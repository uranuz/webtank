module webtank.db.exception;

/++
$(LANG_EN Exception class for database)
$(LANG_RU Класс исключений при работе с БД)
+/
class DBException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}