module webtank.net.http.input;

import std.json, std.socket;
import std.typecons: tuple;

import webtank.net.http.cookie, webtank.net.uri, webtank.net.web_form, webtank.net.http.http, webtank.net.http.headers;


// version = cgi_script;

/// Класс для хранения данных HTTP-запроса на стороне сервера,
/// либо полученного ответа на стороне клиента
class HTTPInput
{	
protected:
	// Основные поля
	HTTPHeaders _headers;
	string _messageBody;
	Address _remoteAddress;
	Address _localAddress;
	

	// Производные поля
	URI _uri;
	CookieCollection _cookies;
	FormData _bodyForm;
	FormData _queryForm;
	
	JSONValue _bodyJSON;
	bool _isJSONParsed = false;
	
public:
	this(
		HTTPHeaders headers,
		string messageBody,
		Address remoteAddress,
		Address localAddress
	)
	{
		_headers = headers;
		_messageBody = messageBody;
		_remoteAddress = remoteAddress;
		_localAddress = localAddress;

		if( "cookie" in _headers )
		{
			// Если видим заголовок "cookie" - значит это запрос
			_cookies = parseRequestCookies( _headers["cookie"] );
		}
		else
		{
			// TODO: Добавить разбор cookie из ответа сервера
			_cookies = new CookieCollection();
		}

		_uri = URI( _headers["request-uri"] );
		if( "host" in _headers )
			_uri.authority = _headers["host"];

		_uri.scheme = "http";
	}

	/// Словарь с HTTP-заголовками
	HTTPHeaders headers() @property {
		return _headers;
	}

	///"Сырое" (недекодированое) значение идентификатора запрашиваемого ресурса
	string rawURI() @property {
		return headers["request-uri"];
	}

	///"Тело сообщения" в том виде, каким оно пришло
	string messageBody() @property {
		return _messageBody;
	}

	///Referer - кто знает, тот поймет
	string referer() @property {
		return headers["referer"];
	}

	///Описание клиентской программы и среды
	string userAgent() @property {
		return headers["user-agent"];
	}

	///Структура с информацией об идентификаторе запрашиваемого ресурса
	ref const(URI) uri() @property {
		return _uri;
	}
	
	///Данные HTTP формы переданные через адресную строку
	FormData queryForm() @property
	{
		if( _queryForm is null )
			_queryForm = new FormData(uri.query);
		return _queryForm;
	}

	///Данные HTTP формы переданные в теле сообщения через HTTP методы POST, PUT и др.
	FormData bodyForm() @property
	{	
		if( _bodyForm is null )
			_bodyForm = new FormData(messageBody);
		return _bodyForm;
	}

	//TODO: Реализовать HTTPInput.form
	///Объединённый словарь данных HTTP формы переданных через адресную
	///строку и тело сообщения
	//	FormData form() @property {}

	///Возвращает набор HTTP Cookie для текущего запроса
	CookieCollection cookies() @property {
		return _cookies;
	}

	///Возвращает адрес удалённого узла, с которого пришло сообщение
	Address remoteAddress() @property {
		return _remoteAddress;
	}
	
	///Возвращает адрес *этого* узла, на который пришло сообщение
	Address localAddress() @property {
		return _localAddress;
	}

	///Возвращает тело сообщения обработанное как объект JSON
	JSONValue bodyJSON() @property
	{
		if( !_isJSONParsed)
		{
			try { //Пытаемся распарсить messageBody в JSON
				_bodyJSON = parseJSON(messageBody);
			} catch( JSONException e ) {
				_bodyJSON = JSONValue.init;
			} finally {
				_isJSONParsed = true;
			}
		}

		return _bodyJSON;
	}

} 

immutable(size_t) startBufLength = 10_240;
immutable(size_t) messageBodyLimit = 4_194_304;

//Функция принимает данные из сокета и возвращает экземпляр HTTPInput
//или кидается исключениями при ошибках
auto readHTTPMessageFromSocket(Socket sock)
{
// 	size_t bytesRead;
	char[] startBuf;
	startBuf.length = startBufLength;

	//Читаем из сокета в буфер
// 	bytesRead =
	sock.receive(startBuf);
	//TODO: Проверить сколько байт прочитано

	auto headersParser = new HTTPHeadersParser(startBuf.idup);
	auto headers = headersParser.getHeaders();

	if( headers is null )
		throw new HTTPException(
			"Request headers buffer is too large or is empty or malformed!!!",
			400 //400 Bad Request
		);

	//Определяем длину сообщения
	size_t contentLength = headers.contentLength;

	//Проверяем размер сообщения
	if( contentLength > messageBodyLimit )
	{
		throw new HTTPException(
			"Content length is too large!!!",
			413 //413 Request Entity Too Large
		);
	}

	string messageBody;
	char[] bodyBuf;
	size_t extraBytesInHeaderBuf = startBufLength - headersParser.headerData.length;
	//Нужно определить сколько ещё нужно прочитать
	if( contentLength > extraBytesInHeaderBuf )
	{
		bodyBuf.length = contentLength - extraBytesInHeaderBuf + 20;
		size_t received = sock.receive(bodyBuf);
		messageBody = headersParser.bodyData ~ bodyBuf[0..received].idup;
	}
	else
	{
		messageBody = headersParser.bodyData;
	}

	return tuple!("headers", "messageBody")(headers, messageBody);
}

// Всевдоним класса для совместимости со старым кодом
alias ServerRequest = HTTPInput;