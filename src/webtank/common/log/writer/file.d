module webtank.common.log.writer.file;

import webtank.common.log.consts: LogLevel;
import webtank.common.log.event: LogEvent;
import webtank.common.log.writer.iface: LogWriter;

/++
$(LANG_EN
	LogWriter that outputs information into log file
)
$(LANG_RU
	Логгер для записи информации в файл журнала
)
+/
class FileLogWriter: LogWriter
{
	import std.stdio: File;
	import std.datetime: Date, Clock;

protected:
	LogLevel _logLevel;
	string _filePrefix;
	Date _fileDate;
	File _file;

public:

	this(string fileName, LogLevel logLevel) {
		_init(fileName, logLevel);
	}

	this(string fileName, LogLevel logLevel) shared
	{
		synchronized {
			(cast(FileLogWriter) this)._init(fileName, logLevel);
		}
	}

	private void _init()(string fileName, LogLevel logLevel)
	{
		_filePrefix = fileName;
		_logLevel = logLevel;
		_fileDate =  cast(Date) Clock.currTime();
		_file = _getLogFile(true);
	}

	private auto _getLogFile()(bool force = false)
	{
		import std.path: dirName, stripExtension, extension;
		import std.file: mkdirRecurse, exists;
		import std.exception: enforce;

		Date currDate = cast(Date) Clock.currTime();
		if( !_file.isOpen() || currDate.day != _fileDate.day || force )
		{
			_file.close();
			_fileDate = currDate;
			string fileName = stripExtension(_filePrefix) ~ "_" ~ _fileDate.toISOExtString() ~ extension(_filePrefix);
			string dir = dirName(fileName);
			if( !exists(dir) ) {
				mkdirRecurse(dir);
			}
			_file = File(fileName, "a");
		}
		enforce(_file.isOpen(), "Error while writing to log file!!!");
		return _file;
	}

	///Добавление записи в лог
	override void writeEvent(LogEvent event)
	{
		import std.conv: text;

		if( ( cast(int) event.type ) < ( cast(int) _logLevel ) )
		{
			string message =
				"//---------------------------------------\r\n"
				~ event.timestamp.toISOExtString()
				~ " [" ~ event.type.text ~ "] " ~ event.file ~ ":" ~ event.line.text
				~ " " ~ event.prettyFuncName ~ ": " ~ event.title ~ "\r\n"
				~ event.text ~ "\r\n";
			auto logFile = _getLogFile();
			logFile.write(message);
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