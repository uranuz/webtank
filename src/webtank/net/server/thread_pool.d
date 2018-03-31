module webtank.net.server.thread_pool;

import webtank.net.http.handler: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.common.loger: Loger;
import webtank.net.server.common: ProcessRequestImpl, ensureBindSocket, makeErrorMsg;

import std.parallelism: TaskPool, task;
import std.socket: Socket, TcpSocket, InternetAddress, socket_t, AddressFamily;

// Web-сервер, использующий стандартный пул задач Phobos
class ThreadPoolServer
{
protected:
	ushort _port = 8082;
	socket_t _socketHandle;
	IHTTPHandler _handler;
	size_t _threadCount;
	Loger _loger;
	bool _isShared;
	Socket _listener;
	TaskPool _taskPool;

public:
	this(ushort port, IHTTPHandler handler, Loger loger, size_t threadCount)
	{
		_port = port;
		_handler = handler;
		_threadCount = threadCount;
		_loger = loger;
		_isShared = false;
	}

	this(socket_t socketHandle, IHTTPHandler handler, Loger loger, size_t threadCount)
	{
		_socketHandle = socketHandle;
		_handler = handler;
		_threadCount = threadCount;
		_loger = loger;
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
					this._loger.crit(`accepted socket is null`);
					continue;
				}

				_taskPool.put(task(&this._processRequest, client));
			}
			catch(Throwable exc)
			{
				this._loger.fatal( makeErrorMsg(exc) );
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