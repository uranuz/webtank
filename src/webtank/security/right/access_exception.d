module webtank.security.right.access_exception;

import webtank.security.exception: SecurityException;

// Внутренняя ошибка системы проверки доступа, которая говорит проблемах в самой системе
class AccessSystemException: SecurityException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

// Ошибка доступа к ресурсу, на который наложены ограничения по правам
class AccessException: SecurityException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}