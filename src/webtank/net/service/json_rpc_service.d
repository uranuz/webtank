module webtank.net.service.json_rpc_service;

import webtank.common.loger;
import webtank.net.http.context;
import webtank.net.http.json_rpc_handler;
import webtank.net.http.handler;
import webtank.net.service.config;
import webtank.net.service.iface;
import webtank.net.utils: makeErrorMsg;
import webtank.security.access_control;
import webtank.security.right.iface.controller: IRightController;


import std.json: JSONValue, parseJSON;

// Класс основного сервиса работающего по протоколу JSON-RPC.
// Служит для чтения и хранения конфигурации, единого доступа к логам,
// маршрутизации и выполнения аутентификации запросов
class JSON_RPCService: IWebService
{
	mixin ServiceConfigImpl;
protected:
	string _serviceName;

	HTTPRouter _rootRouter;
	JSON_RPC_Router _jsonRPCRouter;
	URIPageRouter _pageRouter;

	/// Основной объект для ведения журнала сайта
	Loger _loger;

	// Объект для логирования драйвера базы данных
	Loger _databaseLoger;

	IAccessController _accessController;
	IRightController _rights;

public:
	this(string serviceName, IAccessController accessController, IRightController rights)
	{
		import std.exception: enforce;
		
		_serviceName = serviceName;
		readConfig();
		_startLoging();

		_rootRouter = new HTTPRouter;
		enforce("siteJSON_RPC" in virtualPaths, `Failed to get JSON-RPC virtual path!`);
		_jsonRPCRouter = new JSON_RPC_Router( virtualPaths["siteJSON_RPC"] ~ "{remainder}" );
		_rootRouter.addHandler(_jsonRPCRouter);

		enforce("siteWebFormAPI" in virtualPaths, `Failed to get web-form API virtual path!`);
		_pageRouter = new URIPageRouter( virtualPaths["siteWebFormAPI"] ~ "{remainder}" );
		_rootRouter.addHandler(_pageRouter);

		_accessController = accessController;
		_rights = rights;
		_subscribeRoutingEvents();
	}

	private void _startLoging()
	{
		import std.exception: enforce;

		if( !_loger )
		{
			auto eventLogParamPtr = "siteEventLogFile" in _fileSystemPaths;
			enforce(eventLogParamPtr, `Failed to get event log file path!`);
			_loger = new ThreadedLoger(cast(shared) new FileLoger(*eventLogParamPtr, LogLevel.info));
		}

		if( !_databaseLoger )
		{
			auto databaseLogParamPtr = "siteDatabaseLogFile" in _fileSystemPaths;
			enforce(databaseLogParamPtr, `Failed to get database log file path!`);
			_databaseLoger = new ThreadedLoger(cast(shared) new FileLoger(*databaseLogParamPtr, LogLevel.dbg));
		}
	}

	override Loger loger() @property
	{
		assert(_rootRouter, `Main service loger is not initialized!`);
		return _loger;
	}

	import webtank.db.database: DBLogInfo, DBLogInfoType;
	// Метод перенаправляющий логи БД в файл
	void databaseLogerMethod(DBLogInfo logInfo)
	{
		import std.datetime;
		import std.conv: text;
		
		if( !_databaseLoger ) {
			return;
		}
		LogEvent wtLogEvent;
		final switch(logInfo.type) {
			case DBLogInfoType.info: wtLogEvent.type = LogEventType.dbg; break;
			case DBLogInfoType.warn: wtLogEvent.type = LogEventType.warn; break;
			case DBLogInfoType.error: wtLogEvent.type = LogEventType.error; break;
		}

		wtLogEvent.text = `Database driver: ` ~ logInfo.msg;
		wtLogEvent.timestamp = std.datetime.Clock.currTime();

		_databaseLoger.writeEvent(wtLogEvent);
	}

	private void _subscribeRoutingEvents()
	{
		import std.exception: assumeUnique;
		import std.conv;

		// Логирование приходящих JSON-RPC запросов для отладки
		_jsonRPCRouter.onPostPoll ~= ( (HTTPContext context, bool) {
			import std.conv: to;
			string msg = "Received JSON-RPC request. Headers:\r\n" ~ context.request.headers.toAA().to!string;
			debug msg ~=  "\r\nMessage body:\r\n" ~ context.request.messageBody;

			_loger.info(msg);
		});

		// Логирование приходящих web-form API запросов для отладки
		_pageRouter.onPostPoll ~= ( (HTTPContext context, bool) {
			import std.conv: to;
			string msg = "Received JSON-RPC request. Headers:\r\n" ~ context.request.headers.toAA().to!string;
			debug msg ~=  "\r\nMessage body:\r\n" ~ context.request.messageBody;

			_loger.info(msg);
		});

		//Обработка ошибок в JSON-RPC вызовах
		_rootRouter.onError.join(&this._handleError);
		_jsonRPCRouter.onError.join(&this._handleError);
		_pageRouter.onError.join(&this._handleError);
	}

	// Обработчик пишет информацию о возникших ошибках при выполнении в журнал
	private bool _handleError(Throwable error, HTTPContext)
	{
		auto messages = makeErrorMsg(error);
		loger.error(messages.details);

		return true;
	}

	override HTTPRouter rootRouter() @property
	{
		assert(_rootRouter, `Main service root router is not initialized!`);
		return _rootRouter;
	}

	JSON_RPC_Router JSON_RPCRouter() @property
	{
		assert(_jsonRPCRouter, `Main service JSON-RPC router is not initialized!`);
		return _jsonRPCRouter;
	}

	URIPageRouter pageRouter() @property
	{
		assert(_pageRouter, `Main service page router is not initialized!`);
		return _pageRouter;
	}

	IAccessController accessController() @property
	{
		assert(_accessController, `Main service access controller is not initialized!`);
		return _accessController;
	}

	override IRightController rightController() @property
	{
		assert(_rights, `Main service rights controller is not initialized!`);
		return _rights;
	}

	override void stop()
	{
		if( _loger ) {
			_loger.stop();
		}

		if( _databaseLoger ) {
			_databaseLoger.stop();
		}
	}
}