module webtank.security.right.access_exception;

import webtank.security.exception: SecurityException;

// Ошибка доступа к ресурсу, на который наложены ограничения по правам
class AccessException: SecurityException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}