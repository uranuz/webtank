module webtank.net.server.thread_pool;

import webtank.net.http.handler.iface: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.common.log.writer: LogWriter;
import webtank.net.server.common: processRequest, ensureBindSocket;
import webtank.net.service.iface: IWebService;
import webtank.net.server.iface: IWebServer;
import webtank.net.utils: makeErrorMsg;

import std.parallelism: TaskPool, task;
import std.socket: Socket, TcpSocket, InternetAddress, AddressFamily, SocketShutdown;
version(Posix)
	import std.socket: socket_t;
else
{
	alias socket_t = size_t; // Workaround to compile on Windows
}

// Web-сервер, использующий стандартный пул задач Phobos
class ThreadPoolServer: IWebServer
{
protected:
	ushort _port = 8082;
	socket_t _socketHandle;
	size_t _threadCount;
	bool _isShared;
	IWebService _service;
	Socket _listener;
	TaskPool _taskPool;
	bool _isStopped = false;

public:
	this(ushort port, IWebService srv, size_t threadCount)
	{
		import std.exception: enforce;
		enforce(srv !is null, `Service object expected`);
		_port = port;
		_service = srv;
		_threadCount = threadCount;
		_isShared = false;
	}

	this(socket_t socketHandle, IWebService srv, size_t threadCount)
	{
		import std.exception: enforce;
		enforce(srv !is null, `Service object expected`);
		_socketHandle = socketHandle;
		_service = srv;
		_threadCount = threadCount;
		_isShared = true;
	}

	private void _runLoop()
	{
		while( !_isStopped )
		{
			//try
			//{
				Socket client = _listener.accept();
				if( client is null )
				{
					_service.log.crit(`accepted socket is null`);
					continue;
				}

				_taskPool.put(task(&processRequest, client, this));
			//}
			//catch(Throwable exc)
			//{
			//	_service.log.fatal( makeErrorMsg(exc).userError );
			//	throw exc;
			//}
		}
	}

	override void start()
	{
		if( _isShared ) {
			_listener = new Socket(_socketHandle, AddressFamily.INET);
		} else {
			_listener = new TcpSocket();
		}

		scope(exit)
		{
			if( !_isShared )
			{
				// Закрываем сокет только если он не разделяемый?
				_listener.shutdown(SocketShutdown.BOTH);
				_listener.close();
			}
		}

		if( _isShared ) {
			_listener.listen(1);
		} else {
			_listener.ensureBindSocket(_port);
		}

		_taskPool = new TaskPool(_threadCount);
		scope(exit) {
			_taskPool.stop();
		}
		_isStopped = false;
		_runLoop();
	}

	override void stop() {
		_isStopped = true;
	}

	override IWebService service() @property {
		return _service;
	}
}