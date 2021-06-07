// This file contains portions of code released by Microsoft under the MIT license as part
// of an open-sourcing initiative in 2014 of the C# core libraries.
// The original source was submitted to https://github.com/Microsoft/referencesource

namespace System.ServiceProcess
{
	public struct SessionChangeDescription
	{
		private SessionChangeReason _reason;
		private int _id;

		public this(SessionChangeReason reason, int id)
		{
			_reason = reason;
			_id = id;
		}

		public SessionChangeReason Reason
		{
			get { return _reason; }
		}

		public int SessionId
		{
			get { return _id; }
		}

		public bool Equals(Object obj) =>
			obj == null || !(obj is SessionChangeDescription)
			? false
			: Equals((SessionChangeDescription)obj);

		public int GetHashCode() =>
			(int)_reason ^ _id;

		public bool Equals(SessionChangeDescription changeDescription) =>
			(_reason == changeDescription._reason) && (_id == changeDescription._id);

		public static bool operator==(SessionChangeDescription a, SessionChangeDescription b) =>
			a.Equals(b);

		public static bool operator!=(SessionChangeDescription a, SessionChangeDescription b) =>
			!a.Equals(b);
	}
}
