module webtank.net.web_server;

import std.socket, std.string, std.conv, core.thread, std.datetime;

import webtank.net.http.handler, webtank.net.http.context, webtank.net.http.http;

// Web-сервер порождающий поток на каждое входящее соединение
class WebServer
{
protected:
	ushort _port = 8082;
	IHTTPHandler _handler;
	Loger _loger;

public:
	this(ushort port, IHTTPHandler handler, Loger loger)
	{	_port = port;
		_handler = handler;
		_loger = loger;
	}

	void start()
	{
		import std.stdio: writeln;

		Socket listener = new TcpSocket;
		scope(exit)
		{
			listener.shutdown(SocketShutdown.BOTH);
			listener.close();
		}
		assert(listener.isAlive);

		bool isNotBinded = true;
		writeln( "Попытка привязать серверный сокет к порту " ~ _port.to!string );
		while( isNotBinded ) //Заставляем ОСь дать нам порт
		{
			try {
				listener.bind( new InternetAddress(_port) );
				isNotBinded = false;

				//Ждём, чтобы излишне не загружать систему
				Thread.sleep( dur!("msecs")( 500 ) );
			} catch( std.socket.SocketOSException ) {}
		}
		listener.listen(5);
		writeln("Сервер запущен!");

		while(true) //Цикл приёма соединений через серверный сокет
		{	Socket currSock = listener.accept(); //Принимаем соединение
			auto workingThread = new WorkingThread(currSock, _handler, _loger);
			workingThread.start();
		}

	}
}

import std.socket, std.conv;

import webtank.net.http.request, webtank.net.http.response, webtank.net.http.headers;

//Рабочий процесс веб-сервера
class WorkingThread: Thread
{
protected:
	Socket _socket;
	IHTTPHandler _handler;
	Loger _loger;

public:
	this(Socket sock, IHTTPHandler handler, Loger loger)
	{
		_socket = sock;
		_handler = handler;
		_loger = loger;
		super(&_work);
	}

	private void _work() {
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

string makeErrorMsg( Throwable exc )
{
	return "Exception occurred in file: " ~ exc.file ~ " (" ~ exc.line.to!string ~ "):\r\n" ~ exc.msg ~ "\r\nTraceback info:\r\n" ~ exc.info.to!string;
}

// Реализация приема и обработки запроса из сокета
mixin template ProcessRequestImpl()
{
	private void _processRequest(Socket sock)
	{
		scope(exit)
		{
			sock.shutdown(SocketShutdown.BOTH);
			Thread.sleep( dur!("msecs")( 30 ) );
			sock.close();
		}

		try
		{
			HTTPInput request = readHTTPInputFromSocket(sock);

			if( request is null )
			{
				this._loger.crit( `request is null` );
				return;
			}

			auto context = new HTTPContext( request, new HTTPOutput() );

			//Запуск обработки HTTP-запроса
			this._handler.processRequest( context );

			//Наш сервер не поддерживает соединение
			context.response.headers["connection"] = "close";
			sock.send( context.response.getResponseString() ); //Главное - отправка результата клиенту
		}
		catch( Exception exc )
		{
			this._loger.crit( makeErrorMsg(exc) ); //Хотим знать, что случилось
			sock.send( makeErrorResponse(exc).getResponseString() );

			return; // На эксепшоне не падаем - а тихо-мирно завершаемся
		}
		catch( Throwable exc )
		{
			this._loger.fatal( makeErrorMsg(exc) ); //Хотим знать, что случилось
			sock.send( makeErrorResponse(exc).getResponseString() );

			throw exc; // С Throwable не связываемся - и просто роняем Thread
		}
	}
}

import webtank.common.loger: Loger;

// Web-сервер, использующий стандартный пул задач Phobos
class WebServer2
{
protected:
	IHTTPHandler _handler;
	Socket _listener;
	TaskPool _taskPool;
	size_t _threadCount;
	ushort _port = 8082;
	Loger _loger;

public:
	this( ushort port, IHTTPHandler handler, Loger loger, size_t threadCount = 5 )
	{	_port = port;
		_handler = handler;
		_threadCount = threadCount;
		_loger = loger;
	}

	void _initServer()
	{
		import std.stdio: writeln;

		_listener = new TcpSocket();
		assert(_listener.isAlive);

		bool isBinded = false;
		writeln( "Попытка привязать серверный сокет к порту " ~ _port.to!string );
		while( !isBinded ) //Заставляем ОСь дать нам порт
		{
			try {
				_listener.bind( new InternetAddress(_port) );
				isBinded = true;

				//Ждём, чтобы излишне не загружать систему
				Thread.sleep( dur!("msecs")( 500 ) );
			} catch( std.socket.SocketOSException ) {}
		}
		_listener.listen(1);
		writeln( "Сервер запущен!" );

		_taskPool = new TaskPool(_threadCount);
	}

	private void _runLoop()
	{
		while( true )
		{
			try
			{
				Socket client = _listener.accept();
				if( client is null )
				{
					this._loger.crit( `accepted socket is null` );
					continue;
				}

				auto newTask = task( &this._processRequest, client );
				_taskPool.put( newTask );
			}
			catch( Throwable exc )
			{
				this._loger.fatal( makeErrorMsg(exc) );
				throw exc;
			}
		}
	}

	void start()
	{
		_initServer();
		_runLoop();
	}

	mixin ProcessRequestImpl;
}
