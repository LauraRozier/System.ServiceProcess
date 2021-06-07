// This file contains portions of code released by Microsoft under the MIT license as part
// of an open-sourcing initiative in 2014 of the C# core libraries.
// The original source was submitted to https://github.com/Microsoft/referencesource

using System.Threading;

namespace System.ServiceProcess
{
	public class ServiceBase : IDisposable
	{
		/// Indicates the maximum size for a service name.
		public const int MaxNameLength = 80;

		private NativeMethods.SERVICE_STATUS _status = .();
		private SERVICE_STATUS_HANDLE _statusHandle;
		private NativeMethods.ServiceControlCallback _commandCallback ~ delete _;
		private NativeMethods.ServiceControlCallbackEx _commandCallbackEx ~ delete _;
		private NativeMethods.ServiceMainCallback _mainCallback ~ delete _;
		private char8* _handleName;
		private WaitEvent _startCompletedSignal ~ delete _;
		protected bool _startFailedException;
		private int _acceptedCommands;
		private bool _autoLog;
		private String _serviceName ~ delete _;
		private EventLog _eventLog ~ delete _;
		private bool _nameFrozen;          // set to true once we've started running and ServiceName can't be changed any more.        
		private bool _commandPropsFrozen;  // set to true once we've use the Can... properties.
		private bool _disposed;
		private bool _initialized;
		private bool _isServiceHosted; // If the service is being hosted by MgdSvcHost or some other hosting process.
		private String[] _args ~ delete _;

		/// Creates a new instance of the System.ServiceProcess.ServiceBase class.
		public this() 
		{
		    _acceptedCommands = NativeMethods.ACCEPT_STOP;
		    _autoLog = true;
		    ServiceName = "";
		}

		/// When this method is called from OnStart, OnStop, OnPause or OnContinue, the specified wait hint is passed to the Service Control Manager to avoid having the service marked as hung.
		public void RequestAdditionalTime(int milliseconds) 
		{
		    NativeMethods.SERVICE_STATUS *pStatus = &_status;
			Runtime.Assert(
				_status.currentState == NativeMethods.STATE_CONTINUE_PENDING ||
	            _status.currentState == NativeMethods.STATE_START_PENDING ||
	            _status.currentState == NativeMethods.STATE_STOP_PENDING ||
	            _status.currentState == NativeMethods.STATE_PAUSE_PENDING
			);
	        _status.waitHint = milliseconds;
	        _status.checkPoint++;       
	        NativeMethods.SetServiceStatus(_statusHandle, pStatus);
	    }

		/// Indicates whether to report Start, Stop, Pause, and Continue commands in the event log.
		[ServiceProcessDescription(Res.SBAutoLog)]
		public bool AutoLog 
		{
		    get { return _autoLog; }
		    set { _autoLog = value; }
		}

		/// The termination code for the service.  Set this to a non-zero value before stopping to indicate an error to the Service Control Manager.
		public int ExitCode 
		{
		    get { return _status.win32ExitCode; }
		    set { _status.win32ExitCode = value; }
		}

		/// Indicates whether the service can be handle notifications on computer power status changes.
		public bool CanHandlePowerEvent 
		{
		    get { return (_acceptedCommands & NativeMethods.ACCEPT_POWEREVENT) != 0; }
		    set 
		    {
				Runtime.Assert(!_commandPropsFrozen);

		        if (value)
				{
		            _acceptedCommands |= NativeMethods.ACCEPT_POWEREVENT;
		        }
				else
				{
		            _acceptedCommands &= ~NativeMethods.ACCEPT_POWEREVENT;
				}
		    }
		}

		/// Indicates whether the service can handle Terminal Server session change events.
		public bool CanHandleSessionChangeEvent
		{
		    get { return (_acceptedCommands & NativeMethods.ACCEPT_SESSIONCHANGE) != 0; }
		    set
		    {
				Runtime.Assert(!_commandPropsFrozen);

		        if (value)
				{
		            _acceptedCommands |= NativeMethods.ACCEPT_SESSIONCHANGE;
		        }
				else
				{
		            _acceptedCommands &= ~NativeMethods.ACCEPT_SESSIONCHANGE;
				}
		    }
		} 

		/// Indicates whether the service can be paused and resumed.
		public bool CanPauseAndContinue 
		{
		    get { return (_acceptedCommands & NativeMethods.ACCEPT_PAUSE_CONTINUE) != 0; }
		    set 
		    {
				Runtime.Assert(!_commandPropsFrozen);

		        if (value)
				{
		            _acceptedCommands |= NativeMethods.ACCEPT_PAUSE_CONTINUE;
		        }
				else
				{
		            _acceptedCommands &= ~NativeMethods.ACCEPT_PAUSE_CONTINUE;
				}
		    }
		}

		/// Indicates whether the service should be notified when the system is shutting down.
		public bool CanShutdown 
		{
		    get { return (_acceptedCommands & NativeMethods.ACCEPT_SHUTDOWN) != 0; }
		    set 
		    {
				Runtime.Assert(!_commandPropsFrozen);

		        if (value)
				{
		            _acceptedCommands |= NativeMethods.ACCEPT_SHUTDOWN;
				}
		        else
				{
		            _acceptedCommands &= ~NativeMethods.ACCEPT_SHUTDOWN;
				}
		    }
		}

		/// Indicates whether the service can be stopped once it has started.
		public bool CanStop 
		{
		    get { return (_acceptedCommands & NativeMethods.ACCEPT_STOP) != 0; }
		    set 
		    {
				Runtime.Assert(!_commandPropsFrozen);

		        if (value)
				{
		            _acceptedCommands |= NativeMethods.ACCEPT_STOP;
		        }
				else
				{
		            _acceptedCommands &= ~NativeMethods.ACCEPT_STOP;
				}
		    }
		}

		/// Indicates an System.Diagnostics.EventLog you can use to write noficiation of service command calls, such as Start and Stop, to the Application event log.
		/// This property is read-only.
		public virtual EventLog EventLog 
		{
		    get 
		    {
		        if (_eventLog == null) 
		        {
		            _eventLog = new .();
		            _eventLog.Source = ServiceName;
		            _eventLog.Log = "Application";
		        }

		        return _eventLog;
		    }
		}

		protected SERVICE_STATUS_HANDLE ServiceHandle
		{ 
		    get { return _statusHandle; }
		}

		/// Indicates the short name used to identify the service to the system.
		[ServiceProcessDescription(Res.SBServiceName)]
		public String ServiceName 
		{
		    get { return _serviceName; }
		    set 
		    {
				Runtime.Assert(!_nameFrozen);
				Runtime.Assert(value != "" && ServiceController.ValidServiceName(value));
		        _serviceName = value;
		    }
		}

		/// Disposes of the resources (other than memory ) used by System.ServiceProcess.ServiceBase.
		public void Dispose() 
		{
		    if (_handleName != null)
 				DeleteAndNullify!(_handleName);

		    _nameFrozen = false;
		    _commandPropsFrozen = false;
		    _disposed = true;
		}

		/// When implemented in a derived class, executes when a Continue command is sent to the service by the Service Control Manager.
		/// Specifies the actions to take when a service resumes normal functioning after being paused.
		protected virtual void OnContinue() 
		{
		}

		/// When implemented in a derived class, executes when a Pause command is sent to the service by the Service Control Manager.
		/// Specifies the actions to take when a service pauses.
		protected virtual void OnPause() 
		{
		}

		/// When implemented in a derived class, executes when the computer's power status has changed.
		protected virtual bool OnPowerEvent(PowerBroadcastStatus powerStatus) 
		{
		    return true;
		}

		/// When implemented in a derived class, executes when a Terminal Server session change event is received.
		protected virtual void OnSessionChange(SessionChangeDescription changeDescription)
		{            
		}

		/// When implemented in a derived class, executes when the system is shutting down. Specifies what should happen just prior to the system shutting down.
		protected virtual void OnShutdown() 
		{
		}

		/// When implemented in a derived class, executes when a Start command is sent to the service by the Service Control Manager.
		/// Specifies the actions to take when the service starts.
		protected virtual void OnStart(String[] args) 
		{
		}

		/// When implemented in a derived class, executes when a Stop command is sent to the service by the Service Control Manager.
		/// Specifies the actions to take when a service stops running.
		protected virtual void OnStop() 
		{
		}

		// Delegate type used for the asynchronous call to handle the service stop.
		private delegate void DeferredHandlerDelegate();
		private delegate void DeferredHandlerDelegateCommand(int command);
		private delegate void DeferredHandlerDelegateAdvanced(int eventType, void* eventData);
		private delegate void DeferredHandlerDelegateAdvancedSession(int eventType, int sessionId);

		private void DeferredContinue()
		{
		    NativeMethods.SERVICE_STATUS *pStatus = &_status;
            OnContinue();
            WriteEventLogEntry("Successfully resumed the Windows service.");
            _status.currentState = NativeMethods.STATE_RUNNING;
	        NativeMethods.SetServiceStatus(_statusHandle, pStatus);
		}

		private void DeferredCustomCommand(int command)
		{
	        OnCustomCommand(command);
	        WriteEventLogEntry("Successfully ran the custom command.");
		}

		private void DeferredPause()
		{
		    NativeMethods.SERVICE_STATUS *pStatus = &_status;
            OnPause ();
            WriteEventLogEntry("Successfully paused the Windows service");
            _status.currentState = NativeMethods.STATE_PAUSED;
		    NativeMethods.SetServiceStatus(_statusHandle, pStatus);
		}

		private void DeferredPowerEvent(int eventType, void* eventData)
		{
		    // Note: The eventData pointer might point to an invalid location
		    // This might happen because, between the time the eventData ptr was captured and the time this deferred code runs, the ptr might have already been freed.
	        bool statusResult = OnPowerEvent((PowerBroadcastStatus)eventType);
	        WriteEventLogEntry("Successfully executed the power event");
		}

		private void DeferredSessionChange(int eventType, int sessionId) =>
			OnSessionChange(.((SessionChangeReason)eventType, sessionId));

		/// We mustn't call OnStop directly from the command callback, as this will tie up the command thread for the duration of the OnStop, which can be lengthy.
		/// This is a problem when multiple services are hosted in a single process.
		private void DeferredStop() 
		{
		    NativeMethods.SERVICE_STATUS *pStatus = &_status;
	        int previousState = _status.currentState;

	        _status.checkPoint = 0;
	        _status.waitHint = 0;
	        _status.currentState = NativeMethods.STATE_STOP_PENDING;
	        NativeMethods.SetServiceStatus(_statusHandle, pStatus);

            OnStop();
            WriteEventLogEntry("Successfully executed the stop event");
            _status.currentState = NativeMethods.STATE_STOPPED;
            NativeMethods.SetServiceStatus(_statusHandle, pStatus);
		}

		private void DeferredShutdown() 
		{
	        OnShutdown();
	        WriteEventLogEntry("Successfully executed the shutdown event");

	        if (_status.currentState == NativeMethods.STATE_PAUSED || _status.currentState == NativeMethods.STATE_RUNNING)
	        {
	            NativeMethods.SERVICE_STATUS* pStatus = &_status;
                _status.checkPoint = 0;
                _status.waitHint = 0;
                _status.currentState = NativeMethods.STATE_STOPPED;
                NativeMethods.SetServiceStatus(_statusHandle, pStatus);
	        }
		}

		/// When implemented in a derived class, System.ServiceProcess.ServiceBase.OnCustomCommand executes when a custom command is passed to the service.
		/// Specifies the actions to take when a command with the specified parameter value occurs.
		protected virtual void OnCustomCommand(int command) 
		{
		}

		/// Provides the main entry point for an executable that contains multiple associated services. Loads the specified services into memory so they can be started.
		public static void Run(ServiceBase[] services) 
		{
		    Runtime.Assert(services != null && services.Count > 0);
		    // check if we're on an NT OS
		    Runtime.Assert(Environment.OSVersion.Platform == PlatformID.Win32NT);

		    NativeMethods.SERVICE_TABLE_ENTRY** entriesPointer = new NativeMethods.SERVICE_TABLE_ENTRY*[services.Count + 1]*;
		    NativeMethods.SERVICE_TABLE_ENTRY[] entries = new .[services.Count];
		    bool multipleServices = services.Count > 1;

		    for (int index = 0; index < services.Count; ++index) 
		    {
		        services[index].Initialize(multipleServices);
		        entries[index] = services[index].GetEntry();
				entriesPointer[index] = &entries[index];
		    }

			entriesPointer[services.Count] = &(NativeMethods.SERVICE_TABLE_ENTRY(){
		    	callback = null,
				name = null
			});
		    // While the service is running, this function will never return. It will return when the service is stopped.
		    // After it returns, SCM might terminate the process at any time (so subsequent code is not guaranteed to run).
		    bool res = NativeMethods.StartServiceCtrlDispatcher(entriesPointer);

		    for (ServiceBase service in services)
	            // Propagate exceptions throw during OnStart.
	            // Note that this same exception is also thrown from ServiceMainCallback (so SCM can see it as well).
		        Runtime.Assert(!service._startFailedException);

		    if (!res) 
		        Console.WriteLine("Unable to start from command-line.");

		    for (ServiceBase service in services) 
		    {
		        service.Dispose();

		        if (!res && service.EventLog.Source.Length != 0)
		            service.WriteEventLogEntry("Failed to start the Windows service.", .Error);
		    }
		}

		/// Provides the main entry point for an executable that contains a single service. Loads the service into memory so it can be started.
		public static void Run(ServiceBase service) 
		{
			Runtime.Assert(service != null);
		    Run(new ServiceBase[](service));
		}

		public void Stop() {
		    DeferredStop();
		}

		/// Initializes the service status.
		private void Initialize(bool multipleServices) 
		{
		    if (!_initialized) 
		    {
		        //Cannot register the service with NT service manager if the object has been disposed, since finalization has been suppressed.
				Runtime.Assert(!_disposed);
	            _status.serviceType = !multipleServices
					? NativeMethods.SERVICE_TYPE_WIN32_OWN_PROCESS
					: NativeMethods.SERVICE_TYPE_WIN32_SHARE_PROCESS;
		        _status.currentState = NativeMethods.STATE_START_PENDING;
		        _status.controlsAccepted = 0;
		        _status.win32ExitCode = 0;
		        _status.serviceSpecificExitCode = 0;
		        _status.checkPoint = 0;
		        _status.waitHint = 0;

		        _mainCallback = new => ServiceMainCallback;
		        _commandCallback = new => ServiceCommandCallback;
		        _commandCallbackEx = new => ServiceCommandCallbackEx;
		        _handleName = ServiceName.CStr();

		        _initialized = true;
		    }
		}

		private NativeMethods.SERVICE_TABLE_ENTRY GetEntry() 
		{
		    _nameFrozen = true;
		    NativeMethods.SERVICE_TABLE_ENTRY entry = .() {
				callback = _mainCallback,
				name = _handleName
			};
		    return entry;
		}

		private int ServiceCommandCallbackEx(int command, int eventType, void* eventData, void* eventContext) 
		{
		    int result = NativeMethods.NO_ERROR;

		    switch ( command )
		    {
		        case NativeMethods.CONTROL_POWEREVENT:
		        {
		            DeferredHandlerDelegateAdvanced powerDelegate = scope => DeferredPowerEvent;
		            powerDelegate.Invoke(eventType, eventData);
		            break;
		        }  

		        case NativeMethods.CONTROL_SESSIONCHANGE:
		        {
		            // The eventData pointer can be released between now and when the DeferredDelegate gets called.
		            // So we capture the session id at this point
		            DeferredHandlerDelegateAdvancedSession sessionDelegate = scope => DeferredSessionChange;
		            NativeMethods.WTSSESSION_NOTIFICATION sessionNotification = *(NativeMethods.WTSSESSION_NOTIFICATION*)eventData;
		            sessionDelegate.Invoke(eventType, sessionNotification.sessionId);
		            break;
		        }
		        default:
		        {
		            ServiceCommandCallback(command);
		            break;
		        }
		    }

		    return result;
		}

		/// <include file='doc\ServiceBase.uex' path='docs/doc[@for="ServiceBase.ServiceCommandCallback"]/*' />
		/// <devdoc>
		///     Command Handler callback is called by NT .
		///     Need to take specific action in response to each
		///     command message. There is usually no need to override this method.
		///     Instead, override OnStart, OnStop, OnCustomCommand, etc.
		/// </devdoc>
		/// <internalonly/>
		private void ServiceCommandCallback(int command) 
		{
		    NativeMethods.SERVICE_STATUS *pStatus = &_status; 

	        if (command == NativeMethods.CONTROL_INTERROGATE)
			{
	            NativeMethods.SetServiceStatus(_statusHandle, pStatus);
	        }
			else if (
				_status.currentState != NativeMethods.STATE_CONTINUE_PENDING &&
	            _status.currentState != NativeMethods.STATE_START_PENDING &&
	            _status.currentState != NativeMethods.STATE_STOP_PENDING &&
	            _status.currentState != NativeMethods.STATE_PAUSE_PENDING
			) {
	            switch (command) 
	            {
	                case NativeMethods.CONTROL_CONTINUE:
					{
	                    if (_status.currentState == NativeMethods.STATE_PAUSED) 
	                    {
	                        _status.currentState = NativeMethods.STATE_CONTINUE_PENDING;
	                        NativeMethods.SetServiceStatus(_statusHandle, pStatus);
	                        DeferredHandlerDelegate continueDelegate = scope => DeferredContinue;
	                        continueDelegate.Invoke();
	                    }

	                    break;
					}
	                case NativeMethods.CONTROL_PAUSE:
					{
	                    if (_status.currentState == NativeMethods.STATE_RUNNING) 
	                    {
	                        _status.currentState = NativeMethods.STATE_PAUSE_PENDING;
	                        NativeMethods.SetServiceStatus(_statusHandle, pStatus);
	                        DeferredHandlerDelegate pauseDelegate = scope => DeferredPause;
	                        pauseDelegate.Invoke();
	                    }

	                    break;
					}
	                case NativeMethods.CONTROL_STOP:
					{
	                    int previousState = _status.currentState;
	                    //
	                    // Can't perform all of the service shutdown logic from within the command callback.
	                    // This is because there is a single ScDispatcherLoop for the entire process.  Instead, we queue up an
	                    // asynchronous call to "DeferredStop", and return immediately.  This is crucial for the multiple service
	                    // per process scenario, such as the new managed service host model.
	                    //
	                    if (_status.currentState == NativeMethods.STATE_PAUSED || _status.currentState == NativeMethods.STATE_RUNNING) 
	                    {
	                        _status.currentState = NativeMethods.STATE_STOP_PENDING;
	                        NativeMethods.SetServiceStatus(_statusHandle, pStatus);
	                        // Set our copy of the state back to the previous so that the deferred stop routine
	                        // can also save the previous state.
	                        _status.currentState = previousState;
	                        DeferredHandlerDelegate stopDelegate = scope => DeferredStop;
	                        stopDelegate.Invoke();
	                    }

	                    break;
					}
	                case NativeMethods.CONTROL_SHUTDOWN:
					{
	                    //Same goes for shutdown -- this needs to be very responsive, so we can't have one service tying up the dispatcher loop.
	                    DeferredHandlerDelegate shutdownDelegate = scope => DeferredShutdown;
	                    shutdownDelegate.Invoke();
	                    break;
					}
	                default:
					{
	                    DeferredHandlerDelegateCommand customDelegate = scope => DeferredCustomCommand;
	                    customDelegate.Invoke(command);
	                    break;
					}
	            }
	        }
		}

		/// Need to execute the start method on a thread pool thread.
		/// Most applications will start asynchronous operations in the OnStart method. If such a method is executed in MainCallback thread, the async operations might get canceled immediately.
		private void ServiceQueuedMainCallback() 
		{
	        OnStart(_args);
	        WriteEventLogEntry("Successfully started the Windows service.");
	        _status.checkPoint = 0;
	        _status.waitHint = 0;
	        _status.currentState = NativeMethods.STATE_RUNNING;
		    _startCompletedSignal.Set();
		}

		/// ServiceMain callback is called by NT. It is expected that we register the command handler, and start the service at this point.
		public void ServiceMainCallback(int argCount, char8** argPointer) 
		{
			var argPointer;
		    NativeMethods.SERVICE_STATUS *pStatus = &_status;
	        _args = null;

	        if (argCount > 0) 
	        {
	            //Lets read the arguments
	            // the first arg is always the service name. We don't want to pass that in.
	            _args = new .[argCount - 1];

	            for (int index = 0; index < _args.Count; ++index) 
	            {
	                // we increment the pointer first so we skip over the first argument. 
	                argPointer++;
	                _args[index] = new .(*argPointer);
	            }
	        }

	        // If we are being hosted, then Run will not have been called, since the EXE's Main entrypoint is not called.
	        if (!_initialized) 
	        {
	            _isServiceHosted = true;
	            Initialize (true);
	        }

            _statusHandle = Environment.OSVersion.Version.Major >= 5
				? NativeMethods.RegisterServiceCtrlHandlerEx(ServiceName, _commandCallbackEx, null)
				: NativeMethods.RegisterServiceCtrlHandler(ServiceName, _commandCallback);
	        _nameFrozen = true;

	        if (_statusHandle == null)
	            WriteEventLogEntry("Failed to start the Windows service.", .Error);

	        _status.controlsAccepted = _acceptedCommands;
	        _commandPropsFrozen = true;

	        if ((_status.controlsAccepted & NativeMethods.ACCEPT_STOP) != 0)
	            _status.controlsAccepted = _status.controlsAccepted | NativeMethods.ACCEPT_SHUTDOWN;

	        if (Environment.OSVersion.Version.Major < 5)
	            _status.controlsAccepted &= ~NativeMethods.ACCEPT_POWEREVENT;   // clear Power Event flag for NT4

	        _status.currentState = NativeMethods.STATE_START_PENDING;

	        bool statusOK = NativeMethods.SetServiceStatus(_statusHandle, pStatus);

	        if (!statusOK)
	            return;

	        // Need to execute the start method on a thread pool thread.
	        // Most applications will start asynchronous operations in the
	        // OnStart method. If such a method is executed in the current
	        // thread, the async operations might get canceled immediately
	        // since NT will terminate this thread right after this function
	        // finishes.
	        _startCompletedSignal = new WaitEvent(false);
	        _startFailedException = false;
	        ThreadPool.QueueUserWorkItem(new => ServiceQueuedMainCallback);
	        _startCompletedSignal.WaitFor();

	        if (_startFailedException)
	            // Inform SCM that the service could not be started successfully. (Unless the service has already provided another failure exit code)
	            if (_status.win32ExitCode == 0)
	                _status.win32ExitCode = NativeMethods.ERROR_EXCEPTION_IN_SERVICE;

	        statusOK = NativeMethods.SetServiceStatus(_statusHandle, pStatus);

	        if (!statusOK) 
	        {
	            WriteEventLogEntry("Failed to start the Windows service", .Error);
	            _status.currentState = NativeMethods.STATE_STOPPED;
	            NativeMethods.SetServiceStatus(_statusHandle, pStatus);
	        }
		}

		private void WriteEventLogEntry(String message) 
		{
		    // EventLog failures shouldn't affect the service operation
	        if (AutoLog)
	            this.EventLog.WriteEntry (message);
		}

		private void WriteEventLogEntry(String message, EventLogEntryType errorType) 
		{
		    // EventLog failures shouldn't affect the service operation
	        if (AutoLog)
	            EventLog.WriteEntry(message, errorType);
		}
	}
}
