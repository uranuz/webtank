module webtank.net.http.output;

import std.array;

import webtank.net.http.cookie, webtank.net.uri, webtank.net.http.headers;

///Класс для формирования ответа от HTTP-сервера, либо запроса от клиента
class HTTPOutput
{
protected:
	HTTPHeaders _headers;
	string _messageBody;
	CookieCollection _cookies;

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
	
	///Добавляет строку str к ответу сервера
	void write(string str) {
		_messageBody ~= str;
	}
	
	///Добавляет строку str к ответу сервера
	void opOpAssign(string op: "~")(string str) {
		_messageBody ~= str;
	}
	
	///Устанавливает заголовки для перенаправления
	void redirect(string location)
	{
		_headers["status-code"] = "302";
		_headers["reason-phrase"] = "Found";
		_headers["location"] = location;
	}
	
	string getString() {
		return _getHeaderStr() ~ _messageBody;
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
	string _getHeaderStr()
	{
		import std.conv, std.stdio;
		_headers["content-length"] = _messageBody.length.to!string;
		_headers["content-type"] = "text/html; charset=\"utf-8\"";
		
		return 
			_headers.getStatusLine()
			~ ( _cookies.length > 0 ? _cookies.toResponseHeadersString() ~ "\r\n" : "" )
			~ _headers.getString() ~ "\r\n" ;
	}
}

alias ServerResponse = HTTPOutput;