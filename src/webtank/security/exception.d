module webtank.security.exception;

// Исключение безопасности: аутентификации, авторизация, работа с системой прав
class SecurityException: Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}