module webtank.net.http.output;

import std.array;

import webtank.net.http.cookie, webtank.net.uri, webtank.net.http.headers;

///Класс для формирования ответа от HTTP-сервера, либо запроса от HTTP-клиента
class HTTPOutput
{
protected:
	HTTPHeaders _headers;
	string _messageBody;
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
		return _getResponseHeadersStr() ~ _messageBody;
	}

	/// Возвращает полный запрос, формируемый клиентом
	string getRequestString() {
		return _getRequestHeadersStr() ~ _messageBody;
	}
	
	//Пытаемся очистить ответ, возвращает true, если получилось
	bool tryClear()
	{
		_messageBody = null;
		headers.clear();
		_cookies.clear();
		return true;
	}
	
	bool tryClearBody()
	{
		_messageBody = null;
		return true;
	}
	
	///Куки
	CookieCollection cookies() @property {
		return _cookies;
	}

protected:
	string _getResponseHeadersStr()
	{
		import std.conv: to;
		_headers["content-length"] = _messageBody.length.to!string;
		_headers["content-type"] = "text/html; charset=\"utf-8\"";
		
		return 
			_headers.getStatusLine()
			~ ( _cookies.length > 0 ? _cookies.toResponseHeadersString() ~ "\r\n" : "" )
			~ _headers.getString() ~ "\r\n" ;
	}

	string _getRequestHeadersStr()
	{
		import std.conv: to;
		_headers["content-length"] = _messageBody.length.to!string;
		_headers["content-type"] = "text/html; charset=\"utf-8\"";
		
		return 
			_headers.getRequestLine()
			~ ( _cookies.length > 0 ? _cookies.toRequestHeadersString() ~ "\r\n" : "" )
			~ _headers.getString() ~ "\r\n" ;
	}
}

alias ServerResponse = HTTPOutput;