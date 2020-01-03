module webtank.net.service.json_rpc_service;

import webtank.net.service.iface: IWebService;

// Класс основного сервиса работающего по протоколу JSON-RPC.
// Служит для чтения и хранения конфигурации, единого доступа к логам,
// маршрутизации и выполнения аутентификации запросов
class JSON_RPCService: IWebService
{
	import webtank.net.service.config: ServiceConfigImpl, RoutingConfigEntry;
	import webtank.net.http.handler.router: HTTPRouter;
	import webtank.net.http.handler.json_rpc: JSON_RPC_Router;
	import webtank.net.http.handler.uri_page_router: URIPageRouter;
	import webtank.net.http.context: HTTPContext;
	import webtank.common.loger: Loger, FileLoger, ThreadedLoger, LogEvent, LogEventType, LogLevel;
	import webtank.net.utils: makeErrorMsg;
	import webtank.security.auth.iface.controller: IAuthController;
	import webtank.security.right.iface.controller: IRightController;

	import std.json: JSONValue, parseJSON;

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

	IAuthController _accessController;
	IRightController _rights;

public:
	this(string serviceName)
	{
		import std.exception: enforce;
		enforce(serviceName.length, `Expected service name`);
		
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

		_subscribeRoutingEvents();
	}

	this(string serviceName, IAuthController accessController, IRightController rights)
	{
		import std.exception: enforce;
		enforce(accessController, `Access controller expected`);
		enforce(rights, `Right controller expected`);

		this(serviceName);
		_accessController = accessController;
		_rights = rights;
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
			//debug
			msg ~=  "\r\nMessage body:\r\n" ~ context.request.messageBody;

			_loger.info(msg);
		});

		// Логирование приходящих web-form API запросов для отладки
		_pageRouter.onPostPoll ~= ( (HTTPContext context, bool) {
			import std.conv: to;
			string msg = "Received JSON-RPC request. Headers:\r\n" ~ context.request.headers.toAA().to!string;
			debug msg ~=  "\r\nMessage body:\r\n" ~ context.request.messageBody;

			_loger.info(msg);
		});
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

	IAuthController accessController() @property
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