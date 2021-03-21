module webtank.ivy.service.log_writer;

class IvyLogWriter
{
	import webtank.common.log.writer: LogWriter, LogEvent, LogEventType, ThreadedLogWriter, FileLogWriter, LogLevel;
	import ivy.log.info: LogInfo;
	import ivy.log.consts: LogInfoType;

protected:
	LogWriter _loger;

public:
	this(LogWriter loger)
	{
		import std.exception: enforce;
		enforce(loger !is null, "Expected log writer");
		
		_loger = loger;
	}

	// Метод перенаправляющий логи шаблонизатора в файл
	void writeEvent(ref LogInfo logInfo)
	{
		import std.datetime: Clock;
		import std.conv: text;

		LogEvent wtLogEvent;
		final switch(logInfo.type) {
			case LogInfoType.info: wtLogEvent.type = LogEventType.dbg; break;
			case LogInfoType.warn: wtLogEvent.type = LogEventType.warn; break;
			case LogInfoType.error: wtLogEvent.type = LogEventType.error; break;
			case LogInfoType.internalError: wtLogEvent.type = LogEventType.crit; break;
		}

		wtLogEvent.text ~= logInfo.msg;
		wtLogEvent.prettyFuncName = logInfo.sourceFuncName;
		wtLogEvent.file = logInfo.sourceFileName;
		wtLogEvent.line = logInfo.sourceLine;
		wtLogEvent.timestamp = Clock.currTime();

		_loger.writeEvent(wtLogEvent);
	}
}