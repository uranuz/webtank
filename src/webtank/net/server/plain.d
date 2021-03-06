module webtank.net.server.plain;

import webtank.net.http.handler.iface: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.common.log.writer: LogWriter;
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

// Простой web-сервер без потоков обрабатывающий одно соединение на процесс
class PlainServer: IWebServer
{
protected:
	ushort _port;
	socket_t _socketHandle;
	IWebService _service;
	Socket _listenSocket;
	bool _isShared = false;
	bool _isStopped = false;

public:
	this(ushort port, IWebService service)
	{
		import std.exception: enforce;
		enforce(service, `Service object expected`);
		_port = port;
		_service = service;
		_isShared = false;
	}

	this(socket_t socketHandle, IWebService service)
	{
		import std.exception: enforce;
		enforce(service, `Service object expected`);
		_socketHandle = socketHandle;
		_service = service;
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
			Socket currSock = listener.accept(); //Принимаем соединение
			processRequest(currSock, this);
		}
	}

	override void stop() {
		_isStopped = true;
	}

	override IWebService service() @property {
		return _service;
	}
}
