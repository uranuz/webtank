module webtank.net.web_server;

import std.socket, std.string, std.conv, core.thread, std.stdio, std.datetime;

import webtank.net.http.handler, webtank.net.http.context, webtank.net.http.http;

// Web-сервер порождающий поток на каждое входящее соединение
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
		listener.listen(5);
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
		bodyBuf.length = contentLength - extraBytesInHeaderBuf + 100;
		size_t received = sock.receive(bodyBuf);
		messageBody = headersParser.bodyData ~ bodyBuf[0..received].idup;
	}
	else
	{
		messageBody = headersParser.bodyData[0..contentLength];
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

	private void _work()
	{
		_processRequest( _socket );
	}
	
	mixin ProcessRequestImpl;
}

import std.parallelism;

ServerResponse makeErrorResponse( Throwable exc )
{
	import std.algorithm: castSwitch;
	import std.conv: text;

	ServerResponse response = new ServerResponse();
	string statusCode;
	string reasonPhrase;
	castSwitch!(
		(HTTPException e)
		{
			statusCode = text( e.HTTPStatusCode );
			reasonPhrase = HTTPReasonPhrases.get( e.HTTPStatusCode, "Absolutely unknown status" );
		},
		(Throwable e)
		{
			statusCode = "500";
			reasonPhrase = HTTPReasonPhrases.get( 500, null );
		},
		() {}
	)(exc);

	response.headers["status-code"] = statusCode;
	response.headers["reason-phrase"] = reasonPhrase;
	response.headers["connection"] = "close";
	response.write(
		`<html><head><title>` ~ statusCode ~ ` ` ~ reasonPhrase ~ `</title></head><body>`
		~ `<h3>` ~ statusCode ~ ` ` ~ reasonPhrase ~ `</h3>`
		~ `<h4>` ~ exc.msg ~ `</h4>`
		~ `<hr><p style="text-align: right;">webtank.net.web_server</p>`
		~ `</body></html>`
	);

	return response;
}

// Реализация приема и обработки запроса из сокета
mixin template ProcessRequestImpl()
{
	private void _processRequest(Socket sock)
	{
		ServerRequest request;

		try {
			request = receiveHTTPRequest(sock);
		}
		catch( Throwable exc )
		{
			sock.send( makeErrorResponse( exc ).getString() );
			return;
		}

		if( request is null )
			return;

		auto context = new HTTPContext( request, new ServerResponse() );

		try {
			//Запуск обработки HTTP-запроса
			this._handler.processRequest( context );
		}
		catch( Throwable exc )
		{
			sock.send( makeErrorResponse( exc ).getString() );
			return;
		}

		//Наш сервер не поддерживает соединение
		context.response.headers["connection"] = "close";
		sock.send( context.response.getString() ); //Главное - отправка результата клиенту

		scope(exit)
		{
			sock.shutdown(SocketShutdown.BOTH);
			Thread.sleep( dur!("msecs")( 30 ) );
			sock.close();
		}
	}
}

// Web-сервер, использующий стандартный пул задач Phobos
class WebServer2
{
protected:
	IHTTPHandler _handler;
	Socket _listener;
	TaskPool _taskPool;
	size_t _threadCount;
	ushort _port = 8082;

public:
	this(ushort port, IHTTPHandler handler, size_t threadCount = 5)
	{	_port = port;
		_handler = handler;
		_threadCount = threadCount;
	}

	void _initServer()
	{
		_listener = new TcpSocket();
		assert(_listener.isAlive);

		bool isBinded = false;
		writeln( "Пытаемся привязать серверный сокет к порту " ~ _port.to!string );
		while( !isBinded )  //Заставляем ОСь дать нам порт
		{	try {
				_listener.bind( new InternetAddress(_port) );
				isBinded = true;

				//Ждём, чтобы излишне не загружать систему
				Thread.sleep( dur!("msecs")( 500 ) );
			} catch(std.socket.SocketOSException) {}
		}
		_listener.listen(1);
		writeln("Сайт стартовал!");

		_taskPool = new TaskPool(_threadCount);
	}

	private void _runLoop()
	{
		while( true )
		{
			Socket client = _listener.accept();
			if( client is null )
				continue;

			auto newTask = task( &this._processRequest, client );
			_taskPool.put( newTask );
		}
	}

	void start()
	{
		_initServer();
		_runLoop();
	}

	mixin ProcessRequestImpl;

}