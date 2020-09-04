module webtank.common.trace_info;

class OverridenTraceInfo: object.Throwable.TraceInfo
{
	private char[][] _backTrace;

	this(char[][] traceInfo) {
		_backTrace = traceInfo;
	}

	override {
		int opApply(scope int delegate(ref const(char[])) dg) const
		{
			int result = 0;
			foreach( i; 0.._backTrace.length )
			{
				result = dg(_backTrace[i]);
				if (result)
					break;
			}
			return result;
		}
		int opApply(scope int delegate(ref size_t, ref const(char[])) dg) const
		{
			int result = 0;
			foreach( i; 0.._backTrace.length )
			{
				result = dg(i, _backTrace[i]);
				if (result)
					break;
			}
			return result;
		}
		string toString() const
		{
			import std.array: join;
			return cast(string) _backTrace.join('\n');
		}
	}
}