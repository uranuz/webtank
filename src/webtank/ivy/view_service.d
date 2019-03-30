module webtank.ivy.view_service;

import webtank.net.service.iface: IWebService;
import webtank.ivy.service_mixin: IIvyServiceMixin;

class IvyViewService: IWebService, IIvyServiceMixin
{
	import webtank.net.service.config: ServiceConfigImpl, RoutingConfigEntry;
	import webtank.net.http.handler.iface: IHTTPHandler, HTTPHandlingResult;
	import webtank.net.http.handler.router: HTTPRouter;
	import webtank.net.http.handler.uri_page_router: URIPageRouter;
	import webtank.net.http.handler.mixins: EventBasedHTTPHandlerImpl;
	import webtank.security.access_control: IAccessController;
	import webtank.security.right.iface.controller: IRightController;
	import webtank.ivy.rights: IvyUserRights;
	import webtank.ivy.user: IvyUserIdentity;

	import ivy.interpreter.data_node: IvyData;
	import webtank.ivy.service_mixin: IvyServiceMixin, ViewServiceURIPageRoute;
	import std.json: JSONValue;
	import std.exception: enforce;

	mixin ServiceConfigImpl;
	mixin IvyServiceMixin;
protected:

	string _serviceName;
	HTTPRouter _rootRouter;
	URIPageRouter _pageRouter;
	Loger _loger;

	IAccessController _accessController;
	IRightController _rights;

public:
	this(string serviceName, string pageURIPatternStr)
	{
		import std.exception: enforce;
		enforce(serviceName.length, `Expected service name`);
		_serviceName = serviceName;
		readConfig(); // Читаем конфиг при старте сервиса
		_startLoging(); // Запускаем логирование сервиса

		// Стартуем шаблонизатор
		_initTemplateCache();

		// Организуем маршрутизацию на сервисе
		_rootRouter = new HTTPRouter;
		_pageRouter = new URIPageRouter(pageURIPatternStr);
		_addPageRoutes();
		_rootRouter.addHandler(_pageRouter);

		_subscribeRoutingEvents();
	}

	this(string serviceName, string pageURIPatternStr, IAccessController accessController, IRightController rights)
	{
		import std.exception: enforce;
		enforce(accessController, `Access controller expected`);
		enforce(rights, `Right controller expected`);
		this(serviceName, pageURIPatternStr);

		_accessController = accessController;
		_rights = rights;
	}

	void _addPageRoutes()
	{
		// Добавляем маршруты для страниц из конфигурационного файла
		foreach( entry; _pageRouting ) {
			_pageRouter.addHandler(new ViewServiceURIPageRoute(entry));
		}
	}

	override HTTPRouter rootRouter() @property {
		return _rootRouter;
	}

	URIPageRouter pageRouter() @property {
		return _pageRouter;
	}

	override Loger loger() @property {
		return _loger;
	}

	private void _startLoging()
	{
		import std.path: buildNormalizedPath;
		import std.exception: enforce;

		enforce("siteLogs" in _fileSystemPaths, `Failed to get logs directory!`);
		if( !_loger ) {
			_loger = new ThreadedLoger(
				cast(shared) new FileLoger(
					buildNormalizedPath( _fileSystemPaths["siteLogs"], "view_service.log" ),
					LogLevel.info
				)
			);
		}

		_startIvyLogging();
	}

	private void _subscribeRoutingEvents()
	{
		import webtank.net.utils: makeErrorMsg;
		_pageRouter.onError.join( (Exception ex, HTTPContext context)
		{
			auto messages = makeErrorMsg(ex);
			loger.error(messages.details);
			renderResult(IvyData(messages.userError), context);
			context.response.headers[`status-code`] = `500`;
			context.response.headers[`reason-phrase`] = `Internal Server Error`;
			return true; // Ошибка обработана
		});
	}

	IAccessController accessController() @property {
		enforce(_accessController !is null, `View service access controller is not initialized!`);
		return _accessController;
	}

	override IRightController rightController() @property {
		enforce(_rights !is null, `View service rights controller is not initialized!`);
		return _rights;
	}

	override void stop()
	{
		if( _loger ) {
			_loger.stop();
		}

		_stopIvyLogging();
	}
}