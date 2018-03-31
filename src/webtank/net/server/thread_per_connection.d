module webtank.net.server.thread_per_connection;

import webtank.net.http.handler: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.common.loger: Loger;
import webtank.net.server.common: ProcessRequestImpl, ensureBindSocket;

import std.socket: Socket, TcpSocket, InternetAddress, SocketShutdown, SocketOSException, socket_t, AddressFamily;
import core.thread: Thread;

// Web-сервер порождающий поток на каждое входящее соединение
class ThreadPerConnectionServer
{
protected:
	ushort _port;
	socket_t _socketHandle;
	IHTTPHandler _handler;
	Loger _loger;
	Socket _listenSocket;
	bool _isShared = false;

public:
	this(ushort port, IHTTPHandler handler, Loger loger)
	{
		_port = port;
		_handler = handler;
		_loger = loger;
		_isShared = false;
	}

	this(socket_t socketHandle, IHTTPHandler handler, Loger loger)
	{
		_socketHandle = socketHandle;
		_handler = handler;
		_loger = loger;
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
			auto workingThread = new ServerWorkingThread(currSock, _handler, _loger);
			workingThread.start();
		}

	}
}

//Рабочий процесс веб-сервера
class ServerWorkingThread: Thread
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
		_processRequest(_socket);
	}

	mixin ProcessRequestImpl;
}