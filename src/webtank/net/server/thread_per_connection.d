module webtank.net.server.thread_per_connection;

import webtank.net.http.handler.iface: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.common.loger: Loger;
import webtank.net.server.common: processRequest, ensureBindSocket;
import webtank.net.service.iface: IWebService;
import webtank.net.server.iface: IWebServer;

import std.socket: Socket, TcpSocket, InternetAddress, SocketShutdown, SocketOSException, AddressFamily;
version(Posix)
	import std.socket: socket_t;
else
{
	alias socket_t = size_t; // Workaround to compile on Windows
}
import core.thread: Thread;

// Web-сервер порождающий поток на каждое входящее соединение
class ThreadPerConnectionServer: IWebServer
{
protected:
	ushort _port;
	socket_t _socketHandle;
	IWebService _service;
	Socket _listenSocket;
	bool _isShared = false;
	bool _isStopped = false;

public:
	this(ushort port, IWebService srv)
	{
		import std.exception: enforce;
		enforce(srv, `Service object expected`);
		_port = port;
		_service = srv;
		_isShared = false;
	}

	this(socket_t socketHandle, IWebService srv)
	{
		import std.exception: enforce;
		enforce(srv, `Service object expected`);
		_socketHandle = socketHandle;
		_service = srv;
		_isShared = true;
	}

	override void start()
	{
		Socket listener;
		if( _isShared ) {
			listener = new Socket(_socketHandle, AddressFamily.INET);
		} else {
			listener = new TcpSocket();
		}
		scope(exit)
		{
			if( !_isShared )
			{
				// Закрываем сокет только если он не разделяемый?
				listener.shutdown(SocketShutdown.BOTH);
				listener.close();
			}
		}
		
		if( _isShared) {
			listener.listen(1);
		} else {
			listener.ensureBindSocket(_port);
		}
		_isStopped = false;

		while( !_isStopped ) //Цикл приёма соединений через серверный сокет
		{
			//Принимаем соединение
			Socket currSock = listener.accept();
			// Запускаем поток обработки
			(new ServerWorkingThread(currSock, this)).start();
		}

	}

	override void stop() {
		_isStopped = true;
	}

	override IWebService service() @property {
		return _service;
	}
}

//Рабочий процесс веб-сервера
class ServerWorkingThread: Thread
{
protected:
	Socket _socket;
	IWebServer _server;

public:
	this(Socket sock, IWebServer srv)
	{
		import std.exception: enforce;
		enforce(sock, `Socket object expected`);
		enforce(srv, `Server object expected`);
		_socket = sock;
		_server = srv;
		super(&_work);
	}

	private void _work() {
		processRequest(_socket, _server);
	}
}