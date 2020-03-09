module webtank.net.http.output;

///Класс для формирования ответа от HTTP-сервера, либо запроса от HTTP-клиента
class HTTPOutput
{
	import webtank.net.http.headers.cookie: CookieCollection;
	import webtank.net.uri: URI;
	import webtank.net.http.headers.headers: HTTPHeaders;
	import webtank.net.http.headers.consts: HTTPHeader;
	import webtank.net.http.consts: HTTPStatus, HTTPReasonPhrases;

	import std.array: Appender, appender;

protected:
	HTTPHeaders _headers;
	Appender!string _messageBody;
	URI _requestURI;

public:
	this()
	{
		_headers = new HTTPHeaders;
	}

	///HTTP заголовки
	HTTPHeaders headers() @property {
		return _headers;
	}

	/// HTTP-метод: GET, POST и т.п. Свойство для чтения
	string method() @property {
		return _headers[HTTPHeader.Method];
	}
	/// HTTP-метод: GET, POST и т.п. Свойство для записи
	void method(string value) @property {
		_headers[HTTPHeader.Method] = value;
	}

	/// Свойство для чтения идентификатора ресурса в виде структуры URI
	URI requestURI() @property {
		return _requestURI;
	}
	/// Свойство для записи идентификатора ресурса в виде структуры URI
	void requestURI(URI value) @property {
		_requestURI = value;
		_headers[HTTPHeader.RequestURI] = value.rawQuery;
	}

	/// Свойство для чтения идентификатора ресурса в виде строки
	string rawRequestURI() @property {
		return _headers[HTTPHeader.RequestURI];
	}
	/// Свойство для записи идентификатора ресурса в виде строки
	void rawRequestURI(string value) @property {
		_requestURI = URI(value);
		_headers[HTTPHeader.RequestURI] = value;
	}

	///Добавляет строку str к сообщению ответа сервера, либо запроса клиента
	final void put(string str) {
		_messageBody.put(str);
	}

	final void put(char ch) {
		_messageBody.put(ch);
	}

	/// Устанавливает заголовки для перенаправления запроса HTTP-клиента
	/// на другой ресурс location
	void redirect(string location)
	{
		import webtank.net.uri: URI;
		import std.exception: enforce;
		if( location.length == 0 )
			return;

		enforce(
			URI.isValid(location),
			`Нельзя сформировать HTTP-перенаправление на некорректный URI: ` ~ location);
		_headers.statusCode = HTTPStatus.Found;
		_headers[HTTPHeader.Location] = location;
	}

	// Возвращает полный запрос HTTP-клиента, либо ответ HTTP-сервера
	string getString() {
		return _getHeadersStr() ~ _messageBody.data;
	}

	//Пытаемся очистить ответ, возвращает true, если получилось
	bool tryClear()
	{
		_messageBody = appender!string();
		headers.clear();
		return true;
	}

	bool tryClearBody()
	{
		_messageBody = appender!string();
		return true;
	}

	/// Возвращает набор HTTP Cookie
	CookieCollection cookies() @property {
		return _headers.cookies;
	}

protected:
	private void _assureContentType()
	{
		import std.uni: toLower;
		import webtank.net.utils: parseContentType;
		auto res = parseContentType(_headers.get(HTTPHeader.ContentType, null));
		if( res.mimeType.length == 0 ) {
			res.mimeType = "text/html"; // По дефолту text/html
		}

		if( res.key.length == 0 ) {
			res.key = "charset";
		}

		if( res.key.toLower() == "charset" && res.value.length == 0 ) {
			res.value = "utf-8";
		}

		_headers[HTTPHeader.ContentType] = res.mimeType ~ "; " ~ res.key ~ "=" ~ res.value;
	}

	string _getHeadersStr()
	{
		import std.conv: to;
		_headers[HTTPHeader.ContentLength] = _messageBody.data.length.to!string;
		_assureContentType();

		return _headers.getString() ~ "\r\n";
	}
}
