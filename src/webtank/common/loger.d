/++
$(LANG_EN
	This module is about centralization and automatization of event logging
	in application. This information should be used for programme debug
	and diagnostics.
)
$(LANG_RU
	Модуль создан с целью централизации и автоматизации журналирования
	событий, происходящих во время работы. Полученная информация должна
	использоваться для диагностики и отладки системы.
)
+/
module webtank.common.loger;

/++
$(LANG_EN
	Log event type
)
$(LANG_RU
	Тип журналируемого события
)
+/
enum LogEventType
{
	/++
	$(LANG_EN This is fatal error event. Proper work of application or recovery is impossible)
	$(LANG_RU Фатальная ошибка. Дальнейшая работа или восстановление после неё невозможно)
	+/
	fatal,

	/++
	$(LANG_EN This is critical error event. There serious problems in system. Recovery is hardly possible
		and sometimes can lead to undefined consequences.
	)
	$(LANG_RU Критическая ошибка. Дальнейшая работа существенно затруднена, либо ведёт к неизвестным последствиям)
	+/
	crit,

	/++
	$(LANG_EN This is regular error during execution. Usually it can be handled and programme can continue
		to work in normal mode
	)
	$(LANG_RU Обычная ошибка во время работы. Такая ошибка, как правило, может быть обработана
		и программа может продолжить работу в штатном режиме
	)
	+/
	error,

	/++
	$(LANG_EN This is warning about unexpected or "suspicious" conditions)
	$(LANG_RU Предупреждение о возможных неприятных последствиях или "подозрительных" условиях работы)
	+/
	warn,

	/++
	$(LANG_EN This is informational message about some events in system)
	$(LANG_RU Информационное сообщение о событиях в системе)
	+/
	info,

	/++
	$(LANG_EN This is message with key information for debugging)
	$(LANG_RU Сообщение с основной информацией для отладки)
	+/
	dbg,

	/++
	$(LANG_EN This is super verbose message for traсing and debugging purposes including
		lots of information about programme state, variables, etc.
	)
	$(LANG_RU Сообщение с расширенной информацией для отладки, включающее расширенные
		сведения о состоянии программы, переменных и т.д.
	)
	+/
	trace
}

/++
$(LANG_EN
	Level of verbosity of log
)
$(LANG_RU
	"Уровень логирования" (общая степень детализации журнала)
)
+/
enum LogLevel
{	none,
	fatal,
	crit,
	error,
	warn,
	info,
	dbg,
	trace,
	full
}

/++
$(LANG_EN
	Structure describing log event and containing information to be logged
)
$(LANG_RU
	Структура описывающая журналируемое событие и содержащая информацию,
	которую необходимо "зажурналировать"
)
+/
struct LogEvent
{
	import std.datetime: SysTime;
	import core.thread: ThreadID;
	LogEventType type;   ///Тип записи в журнал
	string mod;       ///Имя модуля
	string file;       ///Имя файла
	size_t line;      ///Номер строки
	string text;      ///Текст записи
	string title;
	ThreadID threadId;
 	string funcName;      ///Имя функции или метода
 	string prettyFuncName;
	SysTime timestamp;     ///Время записи

	// Workaround for being able to send this struct via concurrency send
	void opAssign(LogEvent rhs) shared
	{
		cast() this = rhs;
		//this = cast(shared) rhs; // Gives SEGFAULT - don't know why
	}
}

/++
$(LANG_EN
	Base class for different types of log writers
)
$(LANG_RU
	Базовый клас для различных типов журналирования
)
+/
abstract class Loger
{


public:

	/++
	$(LANG_EN
		This is write log event function that must be reimplemented
		in derived loger classes
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
		import std.datetime;
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
		event.timestamp = std.datetime.Clock.currTime();
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

	abstract void stop();
}

/++
$(LANG_EN
	Loger that outputs information into log file
)
$(LANG_RU
	Логгер для записи информации в файл журнала
)
+/
class FileLoger: Loger
{
	import std.stdio, std.concurrency, std.datetime, std.conv, std.path;
protected:
	LogLevel _logLevel;
	string _filePrefix;
	Date _fileDate;
	File _file;

public:

	this( string fileName, LogLevel logLevel ) {
		_init( fileName, logLevel );
	}

	this( string fileName, LogLevel logLevel ) shared
	{
		synchronized {
			(cast(FileLoger) this)._init( fileName, logLevel );
		}
	}

	private void _init()( string fileName, LogLevel logLevel )
	{
		_filePrefix = fileName;
		_logLevel = logLevel;
		_fileDate =  cast(Date) Clock.currTime();
		_file = _getLogFile(true);
	}

	private auto _getLogFile()( bool force = false )
	{
		import std.path: dirName;
		import std.file: mkdirRecurse, exists;
		Date currDate = cast(Date) Clock.currTime();
		if( currDate.day != _fileDate.day || force )
		{
			_file.close();
			_fileDate = currDate;
			string fileName = stripExtension(_filePrefix) ~ "_" ~ _fileDate.toISOExtString() ~ extension(_filePrefix);
			string dir = dirName(fileName);
			if( !exists(dir) ) {
				mkdirRecurse(dir);
			}
			_file = File( fileName, "a" );
		}
		assert( _file.isOpen(), "Error while writing to log file!!!" );
		return _file;
	}

	///Добавление записи в лог
	override void writeEvent(LogEvent event)
	{
		if( ( cast(int) event.type ) < ( cast(int) _logLevel ) )
		{
			string message =
				"//---------------------------------------\r\n"
				~ event.timestamp.toISOExtString()
				~ " [" ~ std.conv.to!string( event.type ) ~ "] " ~ event.file ~ "("
				~ std.conv.to!string( event.line ) ~ ") " ~ event.prettyFuncName ~ ": " ~ event.title ~ "\r\n"
				~ event.text ~ "\r\n";
			auto logFile = _getLogFile();
			logFile.write( message );
			logFile.flush(); // Сразу сбрасываем С-буфер в файл
		}
	}

	override void stop()
	{
		_getLogFile().flush();
		_getLogFile().close();
	}

	~this() {
		stop();
	}

protected:
}

/++
$(LANG_EN
	Wrapper loger that makes logging work in separate thread
)
$(LANG_RU
	Логер-обертка для работы журналирования в отдельном системном потоке
)
+/
class ThreadedLoger: Loger
{
	import std.concurrency;
public:
	this(shared(Loger) baseLoger) {
		_baseLoger = baseLoger;
	}

	override void writeEvent(LogEvent event)
	{
		if( _logerTid == Tid.init ) {
			_initLogingThread();
		}
		shared(LogEvent) evShared = cast(shared) event;
		send(_logerTid, evShared);
	}

	void _initLogingThread()() {
		synchronized {
			_logerTid = spawn(&_run, thisTid, _baseLoger);
		}
	}

	/++
	$(LANG_EN
		Function stops loger and it's thread.
		Loger object turns into invalid state after it.
	)
	$(LANG_RU
		Функция останавливает работу логера и завершает связанную с ним
		нить исполнения. Логер переходит в нерабочее состояние после этого
	)
	+/
	override void stop()
	{
		if( _logerTid != Tid.init )
		{
			synchronized {
				if( _logerTid != Tid.init ) {
					send(_logerTid, LogStopMsg());
					_logerTid = Tid.init;
				}
			}
		}
		if( _baseLoger )
		{
			synchronized {
				if( _baseLoger ) {
					(cast(Loger)_baseLoger).stop();
				}
			}
		}
	}

	~this() {
		stop();
	}

protected:
	shared(Loger) _baseLoger;
	Tid _logerTid;

	struct LogStopMsg {}

	static void _run( Tid ownerTid, shared(Loger) baseLoger )
	{
		import std.exception: enforce;
		import std.variant: Variant;
		import std.conv: to;
		
		bool cont = true;
		auto loger = cast(Loger) baseLoger;
		while(cont)
		{
			receive(
				(shared(LogEvent) ev) {
					enforce(loger !is null, `Base loger object reference is null!!!`);
					loger.writeEvent(ev);
				},
				(LogStopMsg msg) {
					cont = false;
				},
				(OwnerTerminated e) {
					throw e;
				},
				(Variant val) {
					enforce(loger !is null, `Base loger object reference is null!!!`);
					loger.error(`Unexpected message to loger thread: ` ~ val.to!string);
				}
			);
		}
	}
}
