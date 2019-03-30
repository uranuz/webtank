module webtank.net.http.output;

///Класс для формирования ответа от HTTP-сервера, либо запроса от HTTP-клиента
class HTTPOutput
{
	import webtank.net.http.cookie: CookieCollection;
	import webtank.net.uri: URI;
	import webtank.net.http.headers: HTTPHeaders;

	import std.array: Appender, appender;

protected:
	HTTPHeaders _headers;
	Appender!string _messageBody;
	CookieCollection _cookies;
	URI _requestURI;

public:
	this()
	{
		_cookies = new CookieCollection;
		_headers = new HTTPHeaders;
	}

	///HTTP заголовки
	HTTPHeaders headers() @property {
		return _headers;
	}

	/// HTTP-метод: GET, POST и т.п. Свойство для чтения
	string method() @property {
		return _headers["method"];
	}
	/// HTTP-метод: GET, POST и т.п. Свойство для записи
	void method(string value) @property {
		_headers["method"] = value;
	}

	/// Свойство для чтения идентификатора ресурса в виде структуры URI
	URI requestURI() @property {
		return _requestURI;
	}
	/// Свойство для записи идентификатора ресурса в виде структуры URI
	void requestURI(URI value) @property {
		_requestURI = value;
		_headers["request-uri"] = value.rawQuery;
	}

	/// Свойство для чтения идентификатора ресурса в виде строки
	string rawRequestURI() @property {
		return _headers["request-uri"];
	}
	/// Свойство для записи идентификатора ресурса в виде строки
	void rawRequestURI(string value) @property {
		_requestURI = URI(value);
		_headers["request-uri"] = value;
	}

	///Добавляет строку str к сообщению ответа сервера, либо запроса клиента
	void write(string str) {
		_messageBody ~= str;
	}

	///Добавляет строку str к сообщению ответа сервера, либо запроса клиента
	void opOpAssign(string op: "~")(string str) {
		_messageBody ~= str;
	}

	/// Устанавливает заголовки для перенаправления запроса HTTP-клиента
	/// на другой ресурс location
	void redirect(string location)
	{
		_headers["status-code"] = "302";
		_headers["reason-phrase"] = "Found";
		_headers["location"] = location;
	}

	/// Возвращает полный ответ сервера на запрос клиента
	string getResponseString() {
		return _getResponseHeadersStr() ~ _messageBody.data;
	}

	/// Возвращает полный запрос, формируемый клиентом
	string getRequestString() {
		return _getRequestHeadersStr() ~ _messageBody.data;
	}

	//Пытаемся очистить ответ, возвращает true, если получилось
	bool tryClear()
	{
		_messageBody = appender!string();
		headers.clear();
		_cookies.clear();
		return true;
	}

	bool tryClearBody()
	{
		_messageBody = appender!string();
		return true;
	}

	///Куки
	CookieCollection cookies() @property {
		return _cookies;
	}

protected:
	private void _assureContentType()
	{
		import std.uni: toLower;
		import webtank.net.utils: parseContentType;
		auto res = parseContentType(_headers.get("content-type", null));
		if( res.mimeType.length == 0 ) {
			res.mimeType = "text/html"; // По дефолту text/html
		}

		if( res.key.length == 0 ) {
			res.key = "charset";
		}

		if( res.key.toLower() == "charset" && res.value.length == 0 ) {
			res.value = "utf-8";
		}

		_headers["content-type"] = res.mimeType ~ "; " ~ res.key ~ "=" ~ res.value;
	}

	string _getResponseHeadersStr()
	{
		import std.conv: to;
		_headers["content-length"] = _messageBody.data.length.to!string;
		_assureContentType();

		return
			_headers.getStatusLine()
			~ ( _cookies.length > 0 ? _cookies.toResponseHeadersString() ~ "\r\n" : "" )
			~ _headers.getString() ~ "\r\n" ;
	}

	string _getRequestHeadersStr()
	{
		import std.conv: to;
		_headers["content-length"] = _messageBody.data.length.to!string;
		_assureContentType();

		return
			_headers.getRequestLine()
			~ ( _cookies.length > 0 ? _cookies.toRequestHeadersString() ~ "\r\n" : "" )
			~ _headers.getString() ~ "\r\n" ;
	}
}

alias ServerResponse = HTTPOutput;