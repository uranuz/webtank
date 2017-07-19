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
	URI _requestURI;
	CookieCollection _cookies;
	FormData _bodyForm;
	FormData _queryForm;

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

		if( auto cookiePtr = "cookie" in _headers )
		{
			// Если видим заголовок "cookie" - значит это запрос
			_cookies = parseRequestCookies( *cookiePtr );
		}
		else
		{
			// TODO: Добавить разбор cookie из ответа сервера
			_cookies = new CookieCollection();
		}

		// Для запроса к серверу разбираем идентификатор ресурса
		if( auto uriPtr = "request-uri" in _headers )
		{
			_requestURI = URI( *uriPtr );
			if( auto hostPtr = "host" in _headers )
				_requestURI.authority = *hostPtr;
			
			_requestURI.scheme = "http";
		}
	}

	// Возвращает true, если это экземпляр данных о запросе к HTTP-серверу
	// и false - если это ответ, переданный HTTP-клиенту
	bool isRequest() @property {
		// Если в прочитанных заголовках есть строка запроса - значит это запрос
		return !!("request-line" in _headers);
	}

	/// Словарь с HTTP-заголовками
	HTTPHeaders headers() @property {
		return _headers;
	}

	///"Сырое" (недекодированое) значение идентификатора запрашиваемого ресурса
	string rawRequestURI() @property {
		return headers["request-uri"];
	}

	alias rawURI = rawRequestURI; // Псевдоним для совместимости

	///Структура с информацией об идентификаторе запрашиваемого ресурса
	ref const(URI) requestURI() @property {
		return _requestURI;
	}

	/// HTTP-метод: GET, POST и т.п.
	string method() @property {
		return _headers["method"];
	}

	alias uri = requestURI; // Псевдоним для совместимости

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
	
	///Данные HTTP формы переданные через адресную строку
	FormData queryForm() @property
	{
		if( _queryForm is null ) {
			// Класс FormData ожидает строку запроса в сыром виде, потому что сам её декодирует
			_queryForm = new FormData(uri.rawQuery);
		}
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
} 

immutable(size_t) startBufLength = 10_240;
immutable(size_t) messageBodyLimit = 4_194_304;

//Функция принимает данные из сокета и возвращает экземпляр HTTPInput
//или кидается исключениями при ошибках
auto readHTTPDataFromSocket(Socket sock)
{
	assert( sock, "Socket is null" );

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

HTTPInput readHTTPInputFromSocket(Socket sock)
{
	auto inputData = readHTTPDataFromSocket(sock);
	return new HTTPInput(inputData.headers, inputData.messageBody, sock.remoteAddress, sock.localAddress);
}

// Всевдоним класса для совместимости со старым кодом
alias ServerRequest = HTTPInput;