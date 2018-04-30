module webtank.net.server.thread_pool;

import webtank.net.http.handler: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.common.loger: Loger;
import webtank.net.server.common: ProcessRequestImpl, ensureBindSocket, makeErrorMsg;
import webtank.net.service.iface: IWebService;

import std.parallelism: TaskPool, task;
import std.socket: Socket, TcpSocket, InternetAddress, socket_t, AddressFamily;

// Web-сервер, использующий стандартный пул задач Phobos
class ThreadPoolServer
{
protected:
	ushort _port = 8082;
	socket_t _socketHandle;
	size_t _threadCount;
	bool _isShared;
	Socket _listener;
	TaskPool _taskPool;

public:
	this(ushort port, IWebService service, size_t threadCount)
	{
		assert(service, `Service object expected`);
		_port = port;
		_service = service;
		_threadCount = threadCount;
		_isShared = false;
	}

	this(socket_t socketHandle, IWebService service, size_t threadCount)
	{
		assert(service, `Service object expected`);
		_socketHandle = socketHandle;
		_service = service;
		_threadCount = threadCount;
		_isShared = true;
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
					_service.loger.crit(`accepted socket is null`);
					continue;
				}

				_taskPool.put(task(&this._processRequest, client));
			}
			catch(Throwable exc)
			{
				_service.loger.fatal( makeErrorMsg(exc) );
				throw exc;
			}
		}
	}

	void start()
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
		_runLoop();
	}

	mixin ProcessRequestImpl;
}