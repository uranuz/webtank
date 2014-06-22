module webtank.net.web_server;

import std.socket, std.string, std.conv, core.thread, std.stdio, std.datetime;

import webtank.net.http.handler, webtank.net.http.context, webtank.net.http.http;

class WebServer
{	
protected:
	ushort _port = 8082;
	IHTTPHandler _handler;
	
public:
	this(ushort port, IHTTPHandler handler) 
	{	_port = port;
		_handler = handler;
	}
	
	void start()
	{	Socket listener = new TcpSocket;
		scope(exit) 
		{	listener.shutdown(SocketShutdown.BOTH);
			listener.close();
		}
		assert(listener.isAlive);
		
		bool isNotBinded = true;
		writeln("Пытаемся привязать серверный сокет к порту " ~ _port.to!string );
		while( isNotBinded )  //Заставляем ОСь дать нам порт
		{	try {
				listener.bind( new InternetAddress(_port) );
				isNotBinded = false;
				
				//Ждём, чтобы излишне не загружать систему
				Thread.sleep( dur!("msecs")( 500 ) ); 
			} catch(std.socket.SocketOSException) {}
		}
		listener.listen(1);
		writeln("Сайт стартовал!");
		
		while(true) //Цикл приёма соединений через серверный сокет
		{	Socket currSock = listener.accept(); //Принимаем соединение
			auto workingThread = new WorkingThread(currSock, _handler);
			workingThread.start();
		}
		
	}
}

import std.socket, std.conv;

import webtank.net.http.request, webtank.net.http.response, webtank.net.http.headers;

immutable(size_t) startBufLength = 1024;
immutable(size_t) messageBodyLimit = 4_194_304;

//Функция принимает запрос из сокета и возвращает экземпляр ServerRequest
//или кидается исключениями при ошибках
ServerRequest receiveHTTPRequest(Socket sock)
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
	size_t contentLength = 0;
	if( headers["content-length"] !is null )
	{	try {
			contentLength = headers["content-length"].to!size_t;
		} catch(Exception e) { contentLength = 0; }
	}
	
	//Проверяем размер тела запроса
	if( contentLength > messageBodyLimit )
		throw new HTTPException(
			"Content length is too large!!!",
			413 //413 Request Entity Too Large
		);
	
	string messageBody;
	char[] bodyBuf;
	size_t extraBytesInHeaderBuf = startBufLength - headersParser.headerData.length;
	//Нужно определить сколько ещё нужно прочитать
	if( contentLength > extraBytesInHeaderBuf )
	{	bodyBuf.length = contentLength - extraBytesInHeaderBuf;
		sock.receive(bodyBuf);
		messageBody = headersParser.bodyData ~ bodyBuf.idup;
	}
	else
	{	messageBody = headersParser.bodyData[0..contentLength];
	}
	
	return new ServerRequest( headers, messageBody, sock.remoteAddress, sock.localAddress );
}

//Рабочий процесс веб-сервера
class WorkingThread: Thread
{	
protected:
	Socket _socket;
	IHTTPHandler _handler;
	
public:
	this(Socket sock, IHTTPHandler handler)
	{	_socket = sock;
		_handler = handler;
		super(&_work);
	}
	
protected:
	void _work()
	{	ServerRequest request;
		
// 		try {
			request = receiveHTTPRequest(_socket);
// 		} catch( HTTPException exc ) {
			//TODO: Построить правильный запрос и отправить на обработку ошибок
// 			response.clear();
// 			string statusCodeStr = exc.HTTPStatusCode.to!string;
// 			string reasonPhrase = HTTPReasonPhrases.get(exc.HTTPStatusCode, "Absolutely unknown status");
// 			response.headers["status-code"] = statusCodeStr;
// 			response.headers["reason-phrase"] = reasonPhrase;
// 			response.write(
// 				`<html><head><title>` ~ statusCodeStr ~ ` ` ~ reasonPhrase ~ `</title></head><body>`
// 				~ `<h3>` ~ statusCodeStr ~ ` ` ~ reasonPhrase ~ `</h3>`
// 				~ `<h4>` ~ exc.msg ~ `</h4>`
// 				~ `<hr><p style="text-align: right;">webtank.net.web_server</p>`
// 				~ `</body></html>`
// 			);
// 			return;
// 		}
		//TODO: Исправить на передачу запроса на страницу
		//с ошибкой маршрутизатору, а не просто падение сервера
		if( request is null )
			return; 
		
		auto context = new HTTPContext( request, new ServerResponse(/+&socketSend+/) );

		try {
		//Запуск обработки HTTP-запроса
		_handler.processRequest( context );
		}
		catch (Throwable exc) {
		}
		
		_socket.send( context.response.getString() ); //Главное - отправка результата клиенту

		
		scope(exit)
		{	Thread.sleep( dur!("msecs")( 30 ) );
			_socket.shutdown(SocketShutdown.BOTH);
			_socket.close();
		}
	}
}