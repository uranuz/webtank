module webtank.net.http.response;

import std.array;

import webtank.net.http.cookie, webtank.net.uri, webtank.net.http.headers;

///Класс представляющий ответ сервера
class ServerResponse
{
	///HTTP заголовки ответа сервера
	HTTPHeaders headers;
protected:
	string _respBody;
	ResponseCookies _cookies; 
public:
	
	this(/+ void delegate(string) send +/)
	{	_cookies = new ResponseCookies;
		headers = new HTTPHeaders;
// 		_send = send;
	}
	
	///Добавляет строку str к ответу сервера
	void write(string str)
	{	_respBody ~= str; }
	
	///Добавляет строку str к ответу сервера
	void opOpAssign(string op: "~")(string str)
	{	_respBody ~= str; }
	
	///Устанавливает заголовки для перенаправления
	void redirect(string location)
	{	headers["status-code"] = "302";
		headers["reason-phrase"] = "Found";
		headers["location"] = location;
	}

	//TODO: Разобраться с отправкой ответа клиенту
// 	void flush()
// 	{	if( !_headersSent ) 
// 		{	_headersSent = true;
// 			_send( _getHeaderStr() );
// 		}
// 		_send( _respBody );
// 	}
	
	string getString()
	{	return _getHeaderStr() ~ _respBody;
	}
	
	//Пытаемся очистить ответ, возвращает true, если получилось
	bool tryClear()
	{	_respBody = null;
		headers.clear();
		_cookies.clear();
		return true;
	}
	
	bool tryClearBody()
	{	_respBody = null;
		return true;
	}
	
	///Куки ответа которыми ответит сервер
	ResponseCookies cookies() @property
	{	return _cookies; }

protected:
// 	void delegate(string) _send;
// 	bool _headersSent = false;
	
	string _getHeaderStr()
	{	import std.conv, std.stdio;
		headers["content-length"] = _respBody.length.to!string;
		headers["content-type"] = "text/html; charset=\"utf-8\"";
		
		return 
			headers.getStatusLine()
			~ ( _cookies.length > 0 ? _cookies.toString() ~ "\r\n" : "" )
			~ headers.getString() ~ "\r\n" ;
	}
}