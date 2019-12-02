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

	string[] _webpackLibs;
	size_t[string] _webpackModules;

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
		// Анализируем манифесты webpack'а
		_analyzeWebpackManifests();

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

	/// Вычитываем манифесты для JS-точек входа
	final void _analyzeWebpackManifests()
	{
		import std.algorithm: countUntil, startsWith
		
		;
		import std.file: dirEntries, SpanMode, isFile, exists, read;
		import std.json: parseJSON, JSONValue, JSONType;
		import std.range: dropExactly, dropBackExactly;
		import std.path: buildNormalizedPath;
		string fsPublic = fileSystemPaths[`sitePublic`];
		string manifestsFolder = fsPublic ~ `manifest/`;
		string manifestFileSuffix = `.manifest.json`;

		foreach( string manifestFileName; dirEntries(manifestsFolder, `*` ~ manifestFileSuffix, SpanMode.breadth) )
		{
			if( !isFile(manifestFileName) || !exists(manifestFileName) )
				continue;
			JSONValue jManifest = parseJSON(cast(string) read(manifestFileName));
			enforce(jManifest.type == JSONType.object, `Webpack DllPlugin library manifest expected to be JSON-object: ` ~ manifestFileName);

			auto jLibraryPtr = `name` in jManifest;
			auto jContentPtr = `content` in jManifest;
			enforce(
				jLibraryPtr && jLibraryPtr.type == JSONType.string,
				`Expected name of library in Webpack DllPlugin manifest: ` ~ manifestFileName);
			enforce(
				jContentPtr && jContentPtr.type == JSONType.object,
				`Expected content of library in Webpack DllPlugin manifest: ` ~ manifestFileName);

			string relLibFileName = manifestFileName
				.dropExactly(manifestsFolder.length)
				.dropBackExactly(manifestFileSuffix.length) ~ `.js`;
			string absLibFileName = buildNormalizedPath(fsPublic, relLibFileName);
			enforce(exists(absLibFileName), `Library file name should exist: ` ~ absLibFileName);
			enforce(isFile(absLibFileName), `Library is not a file: ` ~ absLibFileName);

			ptrdiff_t libIndex = _webpackLibs.countUntil(relLibFileName);
			if( libIndex < 0 )
			{
				libIndex = _webpackLibs.length;
				_webpackLibs ~= relLibFileName;
			}
			foreach( string moduleName, val; jContentPtr.object ) {
				_webpackModules[moduleName] = libIndex;
			}
		}
		debug {
			import std.stdio: writeln;
			writeln(`_webpackModules: `, _webpackModules);
			writeln(`_webpackLibs: `, _webpackLibs);
		}
	}

	string getWebpackLibPath(string moduleName)
	{
		if( moduleName.length == 0 ) {
			return null;
		}
		moduleName = `./` ~ moduleName ~ `.js`;
		auto libIndexPtr = moduleName in _webpackModules;
		enforce(libIndexPtr !is null, `Unable to find webpack JS-library for module: ` ~ moduleName);
		size_t libIndex = *libIndexPtr;
		enforce(libIndex < _webpackLibs.length, `Unable to find webpack JS-library with index. Possibly bug in code`);
		return _webpackLibs[libIndex];
	}
}