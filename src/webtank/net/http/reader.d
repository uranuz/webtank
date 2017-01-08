module webtank.net.http.reader;

import webtank.net.http.http, webtank.net.http.headers;
import std.typecons: tuple;
import std.socket: Socket;

immutable(size_t) startBufLength = 10_240;
immutable(size_t) messageBodyLimit = 4_194_304;

//Функция принимает запрос из сокета и возвращает экземпляр ServerRequest
//или кидается исключениями при ошибках
auto readHTTPDataFromSocket(Socket sock)
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

	//Определяем длину тела запроса
	size_t contentLength = headers.contentLength;

	//Проверяем размер тела запроса
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
