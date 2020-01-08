module webtank.net.http.input;

import std.json, std.socket;
import std.typecons: tuple;

import webtank.net.uri;
import webtank.net.web_form;
import webtank.net.http.http;
import webtank.net.http.headers;
import webtank.net.uri_pattern: URIMatchingData;
import webtank.net.http.headers.cookie;

/// Класс для хранения данных HTTP-запроса на стороне сервера,
/// либо полученного ответа на стороне клиента
class HTTPInput
{
	import webtank.net.http.headers.consts: HTTPHeader;
protected:
	// Основные поля
	HTTPHeaders _headers;
	string _messageBody;
	Address _remoteAddress;
	Address _localAddress;

	// Производные поля
	URI _requestURI;
	URIMatchingData _uriMatch;
	IFormData _bodyForm;
	IFormData _queryForm;
	IFormData _form;

public:
	this(
		HTTPHeaders headers,
		string messageBody,
		Address remoteAddress,
		Address localAddress
	)
	{
		import std.exception: enforce;
		enforce(headers !is null, `Expected instance of HTTPHeaders`);

		_headers = headers;
		_messageBody = messageBody;
		_remoteAddress = remoteAddress;
		_localAddress = localAddress;

		// Для запроса к серверу разбираем идентификатор ресурса
		if( auto uriPtr = HTTPHeader.RequestURI in _headers )
		{
			_requestURI = URI( *uriPtr );
			if( auto hostPtr = HTTPHeader.Host in _headers )
				_requestURI.authority = *hostPtr;
			
			_requestURI.scheme = "http";
		}
	}

	/// Словарь с HTTP-заголовками
	HTTPHeaders headers() @property {
		return _headers;
	}

	///"Сырое" (недекодированое) значение идентификатора запрашиваемого ресурса
	string rawRequestURI() @property {
		return headers[HTTPHeader.RequestURI];
	}

	alias rawURI = rawRequestURI; // Псевдоним для совместимости

	///Структура с информацией об идентификаторе запрашиваемого ресурса
	ref const(URI) requestURI() @property {
		return _requestURI;
	}

	/// HTTP-метод: GET, POST и т.п.
	string method() @property {
		return _headers[HTTPHeader.Method];
	}

	alias uri = requestURI; // Псевдоним для совместимости

	///"Тело сообщения" в том виде, каким оно пришло
	string messageBody() @property {
		return _messageBody;
	}

	///Referer - кто знает, тот поймет
	string referer() @property {
		return headers[HTTPHeader.Referer];
	}

	///Описание клиентской программы и среды
	string userAgent() @property {
		return headers[HTTPHeader.UserAgent];
	}
	
	///Данные HTTP формы переданные через адресную строку
	IFormData queryForm() @property
	{
		if( _queryForm is null ) {
			// Класс FormData ожидает строку запроса в сыром виде, потому что сам её декодирует
			_queryForm = new FormData(uri.rawQuery);
		}
		return _queryForm;
	}

	///Данные HTTP формы переданные в теле сообщения через HTTP методы POST, PUT и др.
	IFormData bodyForm() @property
	{	
		if( _bodyForm is null )
			_bodyForm = new FormData(messageBody);
		return _bodyForm;
	}

	/// Объединённый словарь данных HTTP формы переданных через адресную
	/// строку и тело сообщения
	IFormData form() @property
	{
		if( _form is null )
			_form = new AggregateFormData(queryForm, bodyForm);
		return _form;
	}

	URIMatchingData requestURIMatch() @property {
		return _uriMatch;
	}

	void requestURIMatch(URIMatchingData data) @property {
		_uriMatch = data;
	}

	/// Возвращает набор HTTP Cookie
	CookieCollection cookies() @property {
		return _headers.cookies;
	}

	/// Возвращает адрес удалённого узла, с которого пришло сообщение
	Address remoteAddress() @property {
		return _remoteAddress;
	}
	
	/// Возвращает адрес *этого* узла, на который пришло сообщение
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
	import std.conv: text;
	import webtank.net.http.headers.parser: HTTPHeadersParser;
	import webtank.net.http.consts: HTTPStatus;

	assert(sock, "Socket is null");

	char[] startBuf;
	startBuf.length = startBufLength;

	//Читаем из сокета в буфер
	size_t startBufBytesRead = sock.receive(startBuf);

	auto headersParser = new HTTPHeadersParser(cast(string) startBuf[0..startBufBytesRead]);
	auto headers = headersParser.getHeaders();

	//Определяем длину сообщения
	size_t contentLength = headers.contentLength;

	//Проверяем размер сообщения
	if( contentLength > messageBodyLimit )
	{
		throw new HTTPException(
			"Content length is too large!",
			HTTPStatus.PayloadTooLarge
		);
	}

	string messageBody = headersParser.bodyData;
	
	size_t extraBytesInHeaderBuf = startBufBytesRead - headersParser.headerData.length;
	//Нужно определить сколько ещё нужно прочитать
	if( contentLength > extraBytesInHeaderBuf )
	{
		size_t bytesToRead = contentLength - extraBytesInHeaderBuf;
		char[] bodyBuf;
		bodyBuf.length = bytesToRead + 20;
		size_t allReceived = 0;
		// Мы можем прочитать не всё за раз, поэтому делаем это в цикле
		while( allReceived < bytesToRead )
		{
			char[] bodyBufSlice = bodyBuf[allReceived..$]; // Set position where to read into
			size_t received = sock.receive(bodyBufSlice);
			if( received == 0 ) break; // Remote side closed connection
			if( received == Socket.ERROR ) {
				throw new HTTPException("Error on socket", HTTPStatus.ServiceUnavailable);
			}
			allReceived += received;
		}
		if( allReceived < bytesToRead ) {
			throw new HTTPException(
				`Number of bytes read by server ` ~ allReceived.text ~ ` doesn't match requested ` ~ bytesToRead.text,
				HTTPStatus.ServiceUnavailable);
		}
		messageBody ~= bodyBuf[0..allReceived];
	}

	return tuple!("headers", "messageBody")(headers, messageBody);
}

HTTPInput readHTTPInputFromSocket(Socket sock)
{
	auto inputData = readHTTPDataFromSocket(sock);
	return new HTTPInput(inputData.headers, inputData.messageBody, sock.remoteAddress, sock.localAddress);
}
