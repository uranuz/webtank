module webtank.net.server.thread_per_connection;

import webtank.net.http.handler: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.common.loger: Loger;
import webtank.net.server.common: ProcessRequestImpl, ensureBindSocket;
import webtank.net.service.iface: IWebService;

import std.socket: Socket, TcpSocket, InternetAddress, SocketShutdown, SocketOSException, socket_t, AddressFamily;
import core.thread: Thread;

// Web-сервер порождающий поток на каждое входящее соединение
class ThreadPerConnectionServer
{
protected:
	ushort _port;
	socket_t _socketHandle;
	IWebService _service;
	Socket _listenSocket;
	bool _isShared = false;

public:
	this(ushort port, IWebService service)
	{
		assert(service, `Service object expected`);
		_port = port;
		_service = service;
		_isShared = false;
	}

	this(socket_t socketHandle, IWebService service)
	{
		assert(service, `Service object expected`);
		_socketHandle = socketHandle;
		_service = service;
		_isShared = true;
	}

	void start()
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

		while(true) //Цикл приёма соединений через серверный сокет
		{
			Socket currSock = listener.accept(); //Принимаем соединение
			auto workingThread = new ServerWorkingThread(currSock, _service);
			workingThread.start();
		}

	}
}

//Рабочий процесс веб-сервера
class ServerWorkingThread: Thread
{
protected:
	Socket _socket;

public:
	this(Socket sock, IWebService service)
	{
		assert(sock, `Socket object expected`);
		assert(service, `Service object expected`);
		_socket = sock;
		_service = service;
		super(&_work);
	}

	private void _work() {
		_processRequest(_socket);
	}

	mixin ProcessRequestImpl;
}