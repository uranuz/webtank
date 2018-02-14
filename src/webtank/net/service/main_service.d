module webtank.net.service.main_service;

import webtank.common.loger;
import webtank.net.http.context;
import webtank.net.http.json_rpc_handler;
import webtank.net.http.handler;
import webtank.net.service.config;
import webtank.net.service.iface;
import webtank.net.utils: makeErrorMsg;
import webtank.security.access_control;


import std.json: JSONValue, parseJSON;

// Класс основного сервиса работающего по протоколу JSON-RPC.
// Служит для чтения и хранения конфигурации, единого доступа к логам,
// маршрутизации и выполнения аутентификации запросов
class MainService: IWebService
{
	mixin ServiceConfigImpl;
protected:
	string _serviceName;

	HTTPRouter _rootRouter;
	JSON_RPC_Router _jsonRPCRouter;

	/// Основной объект для ведения журнала сайта
	Loger _loger;

	// Объект для логирования драйвера базы данных
	Loger _databaseLoger;

	IAccessController _accessController;

public:
	this(string serviceName, IAccessController accessController)
	{
		_serviceName = serviceName;
		readConfig();
		_startLoging();

		_rootRouter = new HTTPRouter;
		assert( "siteJSON_RPC" in _virtualPaths, `Failed to get JSON-RPC virtual path!` );
		_jsonRPCRouter = new JSON_RPC_Router( _virtualPaths["siteJSON_RPC"] ~ "{remainder}" );
		_rootRouter.addHandler(_jsonRPCRouter);

		_accessController = accessController;
		_subscribeRoutingEvents();
	}

	private void _startLoging()
	{
		if( !_loger ) {
			assert( "siteEventLogFile" in _fileSystemPaths, `Failed to get event log file path!` );
			_loger = new ThreadedLoger( cast(shared) new FileLoger(_fileSystemPaths["siteEventLogFile"], LogLevel.info) );
		}

		if( !_databaseLoger ) {
			assert( "siteDatabaseLogFile" in _fileSystemPaths, `Failed to get database log file path!` );
			_databaseLoger = new ThreadedLoger( cast(shared) new FileLoger(_fileSystemPaths["siteDatabaseLogFile"], LogLevel.dbg) );
		}
	}

	override Loger loger() @property {
		assert( _rootRouter, `Main service loger is not initialized!` );
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

		// Обработчик выполняет аутентификацию и устанавливает полученный "билет" в контекст запроса
		_rootRouter.onPostPoll ~= (HTTPContext context, bool isMatched) {
			if( isMatched ) {
				context._setuser( _accessController.authenticate(context) );
			}
		};

		// Логирование приходящих JSON-RPC запросов для отладки
		_jsonRPCRouter.onPostPoll ~= ( (HTTPContext context, bool) {
			import std.conv: to;
			string msg = "Received JSON-RPC request. Headers:\r\n" ~ context.request.headers.toAA().to!string;
			debug msg ~=  "\r\nMessage body:\r\n" ~ context.request.messageBody;

			_loger.info(msg);
		});

		//Обработка ошибок в JSON-RPC вызовах
		_rootRouter.onError.join(&this._handleError);
		_jsonRPCRouter.onError.join(&this._handleError);
	}

	// Обработчик пишет информацию о возникших ошибках при выполнении в журнал
	private bool _handleError(Throwable error, HTTPContext)
	{
		auto messages = makeErrorMsg(error);
		loger.error(messages.details);

		throw error;
	}

	override HTTPRouter rootRouter() @property {
		assert( _rootRouter, `Main service root router is not initialized!` );
		return _rootRouter;
	}

	JSON_RPC_Router JSON_RPCRouter() @property {
		assert( _jsonRPCRouter, `Main service JSON-RPC router is not initialized!` );
		return _jsonRPCRouter;
	}

	IAccessController accessController() @property {
		assert( _accessController, `Main service access controller is not initialized!` );
		return _accessController;
	}

}