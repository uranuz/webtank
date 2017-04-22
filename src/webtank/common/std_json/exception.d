module webtank.common.std_json.exception;

//Класс исключения сериализации
class SerializationException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}