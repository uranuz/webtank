module webtank.net.http.request;

import std.json, std.socket;

import webtank.net.http.cookie, webtank.net.uri, webtank.net.web_form, webtank.net.http.headers;

// version = cgi_script;

class ServerRequest  //Запрос к нашему приложению
{	
protected:
	string[string] _cookies; //Куки из запроса
	FormData _bodyForm;
	FormData _queryForm;
	URI _uri;

	JSONValue _bodyJSON;
	bool _isJSONParsed = false;
	
	Address _remoteAddress;
	Address _localAddress;
public:
	this(
		HTTPHeaders headersParam, 
		string messageBodyParam,
		Address remoteAddressParam,
		Address localAddressParam
	)
	{	headers = headersParam;
		messageBody = messageBodyParam;
		_remoteAddress = remoteAddressParam;
		_localAddress = localAddressParam;

		_cookies = parseRequestCookies( headers["cookie"] );

		_uri = URI( headers["request-uri"] );
		if( "host" in headers )
			_uri.authority = headers["host"];

		_uri.scheme = "http";
		
		rawURI = headers["request-uri"];
		referer = headers["referer"];
		userAgent = headers["user-agent"];
	}

	///Структура с информацией об идентификаторе запрашиваемого ресурса
	
	///HTTP заголовки запроса
	HTTPHeaders headers;

	///"Сырое" (недекодированое) значение идентификатора запрашиваемого ресурса
	immutable(string) rawURI;
	///"Тело сообщения" в том виде, каким оно пришло
	immutable(string) messageBody;
	///Referer - кто знает, тот поймет
	immutable(string) referer;
	///Описание клиентской программы и среды
	immutable(string) userAgent;

	ref const(URI) uri() @property
	{	return _uri;
	}
	
	///Данные HTTP формы переданные через адресную строку
	FormData queryForm() @property
	{	if( _queryForm is null )
			_queryForm = new FormData( uri.query );
		return _queryForm;
	}

	///Данные HTTP формы переданные в теле сообщения через HTTP методы POST, PUT и др.
	FormData bodyForm() @property
	{	if( _bodyForm is null )
			_bodyForm = new FormData(messageBody);
		return _bodyForm;
	}

	//TODO: Реализовать HTTPRequest.form
	///Объединённый словарь данных HTTP формы переданных через адресную
	///строку и тело сообщения
//	string[string] form() @property {}

	//TODO: Реализовать HTTPRequest.formMulti
	///Объединённый словарь множественных данных HTTP формы переданных
	///через адресную строку и тело сообщения
	///Используется, когда одному имени соответсвует несколько значений
//	string[][string] formMulti() @property {}

	///Возвращает набор HTTP Cookie для текущего запроса
	ref const(string[string]) cookies() @property const
	{	return _cookies; }

	///Возвращает адрес удалённого узла, с которого пришёл запрос
	Address remoteAddress() @property
	{	return _remoteAddress;
	}
	
	///Возвращает адрес *этого* узла, который обрабатывает запрос
	Address localAddress() @property
	{	return _localAddress;
	}

	///Возвращает тело сообщения обработанное как объект JSON
	JSONValue bodyJSON() @property
	{	if( !_isJSONParsed)
		{	try { //Пытаемся распарсить messageBody в JSON
				_bodyJSON = parseJSON(messageBody);
			} catch (JSONException e) {
				_bodyJSON = JSONValue.init;
			} finally {
				_isJSONParsed = true;
			}
		}
		return _bodyJSON;
	}

} 
