// This file contains portions of code released by Microsoft under the MIT license as part
// of an open-sourcing initiative in 2014 of the C# core libraries.
// The original source was submitted to https://github.com/Microsoft/referencesource

namespace System.ServiceProcess
{
	public enum PowerBroadcastStatus
	{
	    BatteryLow = NativeMethods.PBT_APMBATTERYLOW,
	    OemEvent = NativeMethods.PBT_APMOEMEVENT,
	    PowerStatusChange = NativeMethods.PBT_APMPOWERSTATUSCHANGE,
	    QuerySuspend = NativeMethods.PBT_APMQUERYSUSPEND,
	    QuerySuspendFailed = NativeMethods.PBT_APMQUERYSUSPENDFAILED,
	    ResumeAutomatic = NativeMethods.PBT_APMRESUMEAUTOMATIC,
	    ResumeCritical = NativeMethods.PBT_APMRESUMECRITICAL,
	    ResumeSuspend = NativeMethods.PBT_APMRESUMESUSPEND,
	    Suspend = NativeMethods.PBT_APMSUSPEND,
	}

    public enum ServiceAccount
    {
        LocalService = 0,
        NetworkService = 1,
        LocalSystem = 2,
        User = 3
    }
	
	public enum ServiceControllerStatus
	{
	    ContinuePending = NativeMethods.STATE_CONTINUE_PENDING,
	    Paused = NativeMethods.STATE_PAUSED,
	    PausePending = NativeMethods.STATE_PAUSE_PENDING,
	    Running = NativeMethods.STATE_RUNNING,
	    StartPending = NativeMethods.STATE_START_PENDING,
	    Stopped = NativeMethods.STATE_STOPPED,
	    StopPending = NativeMethods.STATE_STOP_PENDING,
	}

    public enum ServiceStartMode
    {
        Automatic = 2,
        Manual = 3,
        Disabled = 4
    }

	/// Status code describing the reason the session state change notification was sent.
	public enum SessionChangeReason
	{
	    /// A session was connected to the console session.
	    ConsoleConnect = NativeMethods.WTS_CONSOLE_CONNECT,
	    /// A session was disconnected from the console session.
	    ConsoleDisconnect = NativeMethods.WTS_CONSOLE_DISCONNECT,
	    /// A session was connected to the remote session.
	    RemoteConnect = NativeMethods.WTS_REMOTE_CONNECT,
	    /// A session was disconnected from the remote session.
	    RemoteDisconnect = NativeMethods.WTS_REMOTE_DISCONNECT,
	    /// A user has logged on to the session.
	    SessionLogon = NativeMethods.WTS_SESSION_LOGON,
	    /// A user has logged off the session.
	    SessionLogoff = NativeMethods.WTS_SESSION_LOGOFF,
	    /// A session has been locked.
	    SessionLock = NativeMethods.WTS_SESSION_LOCK,
	    /// A session has been unlocked.
	    SessionUnlock = NativeMethods.WTS_SESSION_UNLOCK,
	    /// A session has changed its remote controlled status.
	    SessionRemoteControl = NativeMethods.WTS_SESSION_REMOTE_CONTROL
	}

    public enum ServiceType
    {
        KernelDriver = 1,
        FileSystemDriver = 2,
        Adapter = 4,
        RecognizerDriver = 8,
        Win32OwnProcess = 16,
        Win32ShareProcess = 32,
        InteractiveProcess = 256
    }
}
