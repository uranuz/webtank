module webtank.common.log.event;

import webtank.common.log.consts: LogEventType;

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