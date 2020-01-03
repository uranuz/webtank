module webtank.security.auth.common.exception;

import webtank.security.exception: SecurityException;

// Исключение аутентификации
class AuthException: SecurityException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}