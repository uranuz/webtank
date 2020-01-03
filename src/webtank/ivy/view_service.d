module webtank.ivy.view_service;

import webtank.net.service.iface: IWebService;
import webtank.ivy.service_mixin: IIvyServiceMixin;

class IvyViewService: IWebService, IIvyServiceMixin
{
	import webtank.net.service.config: ServiceConfigImpl, RoutingConfigEntry;
	import webtank.net.http.handler.iface: IHTTPHandler, HTTPHandlingResult;
	import webtank.net.http.handler.router: HTTPRouter;
	import webtank.net.http.handler.web_form_api_page_route: joinWebFormAPI;
	import webtank.net.http.handler;
	import webtank.net.http.handler.uri_page_router: URIPageRouter;
	import webtank.net.http.handler.mixins: EventBasedHTTPHandlerImpl;
	import webtank.security.auth.iface.controller: IAuthController;
	import webtank.security.right.iface.controller: IRightController;
	import webtank.security.auth.client.controller: AuthClientController;
	import webtank.security.right.controller: AccessRightController;
	import webtank.security.right.remote_source: RightRemoteSource;
	import webtank.ivy.access_rule_factory: IvyAccessRuleFactory;
	import webtank.ivy.rights: IvyUserRights;
	import webtank.ivy.user: IvyUserIdentity;

	import ivy.interpreter.data_node: IvyData;
	import webtank.ivy.service_mixin: IvyServiceMixin, ViewServiceURIPageRoute, processViewRequest;
	import std.json: JSONValue, JSONType;
	import std.exception: enforce;

	mixin ServiceConfigImpl;
	mixin IvyServiceMixin;
protected:

	string _serviceName;
	HTTPRouter _rootRouter;
	URIPageRouter _pageRouter;
	Loger _loger;

	IAuthController _accessController;
	IRightController _rights;

	string[] _webpackLibs;
	size_t[string] _webpackModules;

	RoutingConfigEntry _generalTemplateEntry;

public:
	this(string serviceName, string pageURIPatternStr)
	{
		import std.exception: enforce;
		enforce(serviceName.length, `Expected service name`);
		_serviceName = serviceName;
		readConfig(); // Читаем конфиг при старте сервиса
		_startLoging(); // Запускаем логирование сервиса

		// Определяем мастер-шаблон из конфига
		auto genTplModulePtr = "generalTemplateModule" in _serviceConfig;
		auto genTplMethodPtr = "generalTemplateMethod" in _serviceConfig;
		if( genTplModulePtr && genTplModulePtr.type == JSONType.string ) {
			_generalTemplateEntry.ivyModule = genTplModulePtr.str;
		}
		if( genTplMethodPtr && genTplMethodPtr.type == JSONType.string ) {
			_generalTemplateEntry.ivyMethod = genTplMethodPtr.str;
		}

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

		_rootRouter.joinWebFormAPI!getCompiledTemplate("/dyn/server/template");
	}

	this(string serviceName, string pageURIPatternStr, IAuthController accessController, IRightController rights)
	{
		import std.exception: enforce;
		enforce(accessController, `Access controller expected`);
		enforce(rights, `Right controller expected`);
		this(serviceName, pageURIPatternStr);

		_accessController = accessController;
		_rights = rights;
	}

	this(string serviceName, string pageURIPatternStr, bool isSecured)
	{
		import std.exception: enforce;
		enforce(isSecured, `Insecured view service kind in not implemented yet!`);

		this(serviceName, pageURIPatternStr);
		auto authNamePtr = `authService` in this.serviceDeps;
		enforce(authNamePtr !is null && authNamePtr.length > 0, `Authentication service require in serviceDeps config option`);

		_accessController = new AuthClientController;
		_rights = new AccessRightController(
			new IvyAccessRuleFactory(this.ivyEngine),
			new RightRemoteSource(this, *authNamePtr, `accessRight.list`));
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

	IAuthController accessController() @property {
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
		import std.algorithm: countUntil, startsWith;
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
				.dropBackExactly(manifestFileSuffix.length);
			string absLibFileName = buildNormalizedPath(fsPublic, relLibFileName ~ ".js");
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

	override void renderResult(IvyData content, HTTPContext ctx)
	{
		import std.range: empty;
		import std.exception: enforce;
		import std.algorithm: splitter, map, filter;
		import std.string: strip, toLower;
		import std.array: array;

		import webtank.security.right.source_method: getAccessRightList;
		import webtank.security.right.controller: AccessRightController;
		import webtank.common.std_json.to: toStdJSON;
		import webtank.ivy.service_mixin: prepareIvyGlobals;
		import ivy.interpreter.data_node: NodeEscapeState;
		import ivy.json: toIvyJSON;

		import ivy.interpreter.data_node: errorToIvyData;

		// Если есть "мусор" в буфере вывода, то попытаемся его убрать
		ctx.response.tryClearBody();

		// Если не задан мастер-шаблон, либо установлена опция вывода без мастер-шаблона, то выводим без мастер-шаблона. В чем, собственно, логика есть...
		if( _generalTemplateEntry.ivyModule.empty || ctx.request.queryForm.get("generalTemplate", null).toLower() == "no" )
		{
			renderResultToResponse(content, ctx);
			return;
		}

		AccessRightController rightController = cast(AccessRightController) ctx.service.rightController;
		enforce(rightController !is null, `rightController is not of type AccessRightController or null`);
		auto rights = getAccessRightList(rightController.rightSource);
		IvyData ivyRights;
		if( ctx.user.isAuthenticated() )
		{
			foreach( name, val; rights )
			{
				auto jVal = val.toStdJSON();
				ivyRights[name] = jVal.toIvyJSON();
			}
		}
		
		string[] accessRoles = ctx.user.data.get("accessRoles", null)
			.splitter(';')
			.map!(strip)
			.filter!((it) => it.length)
			.array;

		IvyData payload = [
			"content": content,
			"userRightData": IvyData([
				"user": IvyData([
					"id": IvyData(ctx.user.id),
					"name": IvyData(ctx.user.name),
					"accessRoles": IvyData(accessRoles),
					"sessionId": (ctx.user.isAuthenticated()? IvyData("dummy"): IvyData())
				]),
				"right": ivyRights,
				"vpaths": IvyData(ctx.service.virtualPaths)
			]),
			"webpackLib": IvyData(getWebpackLibPath(ctx.junk.get(`moduleName`, null)))
		];

		processViewRequest(ctx, _generalTemplateEntry, payload).then(
			(IvyData ivyRes) {
				renderResultToResponse(ivyRes, ctx);
			},
			(Throwable error) {
				renderResultToResponse(errorToIvyData(error), ctx);
			});
	}

	import webtank.ivy.service_mixin: IIvyServiceMixin;

	static JSONValue getCompiledTemplate(HTTPContext ctx)
	{
		import std.exception: enforce;
		IIvyServiceMixin ivyService = cast(IIvyServiceMixin) ctx.service;
		enforce(ivyService, `Expected instance of IIvyServiceMixin`);
		return ivyService.ivyEngine.getByModuleName(ctx.request.form[`moduleName`]).toStdJSON();
	}
}