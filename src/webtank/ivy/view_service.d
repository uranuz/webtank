module webtank.ivy.view_service;

import webtank.common.loger;
import webtank.common.event;
import webtank.net.service.config;
import webtank.net.service.iface;
import webtank.security.access_control;
import webtank.net.http.handler;
import webtank.net.http.context;
import webtank.net.http.output: HTTPOutput;
import webtank.net.utils;
import webtank.ivy;
import webtank.security.right.iface.controller: IRightController;
import webtank.ivy.rights: IvyUserRights;
import webtank.ivy.user: IvyUserIdentity;

import ivy;
import ivy.interpreter.data_node_render: renderDataNode, DataRenderType;
import webtank.ivy.service_mixin: IvyServiceMixin, IIvyServiceMixin;


class IvyViewService: IWebService, IIvyServiceMixin
{
	mixin ServiceConfigImpl;
	mixin IvyServiceMixin;
protected:
	import std.json: JSONValue;

	string _serviceName;
	HTTPRouter _rootRouter;
	URIPageRouter _pageRouter;
	Loger _loger;

	IAccessController _accessController;
	IRightController _rights;

public:
	this(string serviceName, IAccessController accessController, string pageURIPatternStr, IRightController rights)
	{
		_serviceName = serviceName;
		readConfig(); // Читаем конфиг при старте сервиса
		_startLoging(); // Запускаем логирование сервиса

		// Стартуем шаблонизатор
		_initTemplateCache();

		// Организуем маршрутизацию на сервисе
		_rootRouter = new HTTPRouter;
		_pageRouter = new URIPageRouter(pageURIPatternStr);
		_rootRouter.addHandler(_pageRouter);

		_accessController = accessController;
		_rights = rights;
		_subscribeRoutingEvents();
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
		_pageRouter.onError.join( (Exception ex, HTTPContext context)
		{
			auto messages = makeErrorMsg(ex);
			loger.error(messages.details);
			renderResult(IvyData(messages.userError), context);
			context.response.headers[`status-code`] = `500`;
			context.response.headers[`reason-phrase`] = `Internal Server Error`;
			return true;
		});
	}

	IAccessController accessController() @property {
		assert( _accessController, `View service access controller is not initialized!` );
		return _accessController;
	}

	override IRightController rightController() @property {
		assert( _rights, `View service rights controller is not initialized!` );
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