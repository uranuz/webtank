module webtank.common.log.writer.iface;

import webtank.common.log.consts: LogLevel, LogEventType;
import webtank.common.log.event: LogEvent;

/++
$(LANG_EN
	Base class for different types of log writers
)
$(LANG_RU
	Базовый клас для различных типов журналирования
)
+/
abstract class LogWriter
{


public:

	/++
	$(LANG_EN
		This is write log event function that must be reimplemented
		in derived log classes
	)
	$(LANG_RU
		Функция записи события в журнал, которая должна быть переопределена
		в наследуемом классе логера
	)
	+/
	abstract void writeEvent(LogEvent event);


	/++
	$(LANG_EN
		Common function for writing some messages into log
	)
	$(LANG_RU
		Общая функция для вывода сообщений в журнал
	)
	+/
	void write(	LogEventType eventType, string text, string title = null,
		string file = __FILE__, int line = __LINE__,
		string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__,
		string mod = __MODULE__)
	{
		import std.datetime: Clock;
		import core.thread: Thread, ThreadID;

		LogEvent event;
		event.type = eventType;
		event.text = text;
		event.title = title;
		event.mod = mod;
		event.file = file;
		event.line = line;
		event.funcName = funcName;
		event.prettyFuncName = prettyFuncName;
		event.timestamp = Clock.currTime();
		event.threadId = Thread.getThis().id;

		writeEvent( event );
	}

	void write(Throwable exc, LogEventType eventType)
	{
		import std.datetime: Clock;
		import core.thread: Thread, ThreadID;

		LogEvent event;
		event.type = eventType;
		event.text = exc.msg;
		event.title = typeid(exc).toString();
		event.file = exc.file;
		event.line = exc.line;
		event.timestamp = Clock.currTime();
		event.threadId = Thread.getThis().id;

		writeEvent( event );
	}


	/++
	$(LANG_EN
		Convinience function for writing certain type of event into log
	)
	$(LANG_RU
		Удобная функция для записи определенного типа события в журнал
	)
	+/
	void fatal( string text, string title = null,
		string file = __FILE__, int line = __LINE__,
		string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__,
		string mod = __MODULE__ )
	{	write( LogEventType.fatal, text, title, file, line, funcName, prettyFuncName, mod ); }

	/++
		ditto
	+/
	void crit( string text, string title = null,
		string file = __FILE__, int line = __LINE__,
		string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__,
		string mod = __MODULE__ )
	{	write( LogEventType.crit, text, title, file, line, funcName, prettyFuncName, mod ); }

	/++
		ditto
	+/
	void error( string text, string title = null,
		string file = __FILE__, int line = __LINE__,
		string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__,
		string mod = __MODULE__ )
	{	write( LogEventType.error, text, title, file, line, funcName, prettyFuncName, mod ); }

	/++
		ditto
	+/
	void warn( string text, string title = null,
		string file = __FILE__, int line = __LINE__,
		string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__,
		string mod = __MODULE__ )
	{	write( LogEventType.warn, text, title, file, line, funcName, prettyFuncName, mod ); }

	/++
		ditto
	+/
	void info( string text, string title = null,
		string file = __FILE__, int line = __LINE__,
		string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__,
		string mod = __MODULE__ )
	{	write( LogEventType.info, text, title, file, line, funcName, prettyFuncName, mod ); }

	/++
		ditto
	+/
	void dbg( string text, string title = null,
		string file = __FILE__, int line = __LINE__,
		string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__,
		string mod = __MODULE__ )
	{	write( LogEventType.dbg, text, title, file, line, funcName, prettyFuncName, mod ); }

	/++
		ditto
	+/
	void trace( string text, string title = null,
		string file = __FILE__, int line = __LINE__,
		string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__,
		string mod = __MODULE__ )
	{	write( LogEventType.trace, text, title, file, line, funcName, prettyFuncName, mod ); }

	/++
	$(LANG_EN
		Write exception info to log
	)
	$(LANG_RU
		Записать информацию об исключении в журнал
	)
	+/
	void fatal(Throwable exc) {
		write(exc, LogEventType.fatal);
	}

	/++
		ditto
	+/
	void crit(Throwable exc) {
		write(exc, LogEventType.crit);
	}

	/++
		ditto
	+/
	void error(Throwable exc) {
		write(exc, LogEventType.error);
	}

	/++
		ditto
	+/
	void warn(Throwable exc) {
		write(exc, LogEventType.warn);
	}

	/++
		ditto
	+/
	void info(Throwable exc) {
		write(exc, LogEventType.info);
	}

	/++
		ditto
	+/
	void dbg(Throwable exc) {
		write(exc, LogEventType.dbg);
	}

	/++
		ditto
	+/
	void trace(Throwable exc) {
		write(exc, LogEventType.trace);
	}

	abstract void stop();
}