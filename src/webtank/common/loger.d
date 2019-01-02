/++
$(LOCALE_EN_US
	This module is about centralization and automatization of event logging
	in application. This information should be used for programme debug
	and diagnostics.
)

$(LOCALE_RU_RU
	Модуль создан с целью централизации и автоматизации журналирования
	событий, происходящих во время работы. Полученная информация должна
	использоваться для диагностики и отладки системы.
)
+/
module webtank.common.loger;

/++
$(LOCALE_EN_US
	Log event type
)

$(LOCALE_RU_RU
	Тип журналируемого события
)
+/
enum LogEventType
{
	/++
	$(LOCALE_EN_US This is fatal error event. Proper work of application or recovery is impossible)
	$(LOCALE_RU_RU Фатальная ошибка. Дальнейшая работа или восстановление после неё невозможно)
	+/
	fatal,

	/++
	$(LOCALE_EN_US This is critical error event. There serious problems in system. Recovery is hardly possible
		and sometimes can lead to undefined consequences.
	)
	$(LOCALE_RU_RU Критическая ошибка. Дальнейшая работа существенно затруднена, либо ведёт к неизвестным последствиям)
	+/
	crit,

	/++
	$(LOCALE_EN_US This is regular error during execution. Usually it can be handled and programme can continue
		to work in normal mode
	)
	$(LOCALE_RU_RU Обычная ошибка во время работы. Такая ошибка, как правило, может быть обработана
		и программа может продолжить работу в штатном режиме
	)
	+/
	error,

	/++
	$(LOCALE_EN_US This is warning about unexpected or "suspicious" conditions)
	$(LOCALE_RU_RU Предупреждение о возможных неприятных последствиях или "подозрительных" условиях работы)
	+/
	warn,

	/++
	$(LOCALE_EN_US This is informational message about some events in system)
	$(LOCALE_RU_RU Информационное сообщение о событиях в системе)
	+/
	info,

	/++
	$(LOCALE_EN_US This is message with key information for debugging)
	$(LOCALE_RU_RU Сообщение с основной информацией для отладки)
	+/
	dbg,

	/++
	$(LOCALE_EN_US This is super verbose message for traсing and debugging purposes including
		lots of information about programme state, variables, etc.
	)
	$(LOCALE_RU_RU Сообщение с расширенной информацией для отладки, включающее расширенные
		сведения о состоянии программы, переменных и т.д.
	)
	+/
	trace
}

/++
$(LOCALE_EN_US
	Level of verbosity of log
)

$(LOCALE_RU_RU
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
$(LOCALE_EN_US
	Structure describing log event and containing information to be logged
)

$(LOCALE_RU_RU
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
$(LOCALE_EN_US
	Base class for different types of log writers
)

$(LOCALE_RU_RU
	Базовый клас для различных типов журналирования
)
+/
abstract class Loger
{


public:

	/++
	$(LOCALE_EN_US
		This is write log event function that must be reimplemented
		in derived loger classes
	)

	$(LOCALE_RU_RU
		Функция записи события в журнал, которая должна быть переопределена
		в наследуемом классе логера
	)
	+/
	abstract void writeEvent(LogEvent event);


	/++
	$(LOCALE_EN_US
		Common function for writing some messages into log
	)

	$(LOCALE_RU_RU
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
	$(LOCALE_EN_US
		Convinience function for writing certain type of event into log
	)

	$(LOCALE_RU_RU
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
$(LOCALE_EN_US
	Loger that outputs information into log file
)

$(LOCALE_RU_RU
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
$(LOCALE_EN_US
	Wrapper loger that makes logging work in separate thread
)

$(LOCALE_RU_RU
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
	$(LOCALE_EN_US
		Function stops loger and it's thread.
		Loger object turns into invalid state after it.
	)

	$(LOCALE_RU_RU
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
		bool cont = true;
		auto loger = cast(Loger) baseLoger;
		while(cont)
		{
			receive(
				(LogEvent ev) {
					assert(loger, `Base loger object reference is null!!!`);
					loger.writeEvent(ev);
				},
				(LogStopMsg msg) {
					cont = false;
				},
				(OwnerTerminated e) {
					//loger.write(LogEventType.fatal, "Нить, породившая процесс логера, завершилась!!!");
					throw e;
				}
			);
		}
	}
}
