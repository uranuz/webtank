module webtank.ivy.service.view.service;

import webtank.net.service.iface: IWebService;

class IvyViewService: IWebService
{
	import webtank.net.service.config: IServiceConfig, ServiceConfig;
	import webtank.net.service.api_info_mixin: ServiceAPIInfoMixin;
	import webtank.net.http.handler.iface: IHTTPHandler;
	import webtank.net.http.handler.router: HTTPRouter;
	
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
	import webtank.net.service.consts: ServiceRole;

	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.input: HTTPInput;
	import webtank.net.http.output: HTTPOutput;
	import webtank.net.server.iface: IWebServer;

	import webtank.ivy.service.view.webpack_manifest: WebpackManifest;
	import webtank.ivy.service.view.context: IvyViewServiceContext;

	import webtank.ivy.engine: WebtankIvyEngine;

	import std.json: JSONValue, JSONType;
	import std.exception: enforce;

	import ivy.engine: IvyEngine;	
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.data.async_result: AsyncResult;
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.types.symbol.dir_attr: DirAttr;

	import webtank.net.web_form: IFormData;
	import ivy.types.symbol.iface.callable: ICallableSymbol;

	import webtank.common.log.writer: LogWriter;

	import ivy.engine: SaveStateResult;

	private static immutable DEFAULT_CLASS_METHOD = "render";

	mixin ServiceAPIInfoMixin;
protected:
	ServiceConfig _config;

	LogWriter _loger;

	HTTPRouter _rootRouter;
	URIPageRouter _pageRouter;
	
	IvyEngine _ivyEngine;
	WebpackManifest _webpackManifest;

	IAuthController _accessController;
	IRightController _rights;

	string _appIvyModule;
	string _appIvyMethod;

public:
	this(string serviceName, string pageURIPatternStr)
	{
		_config = new ServiceConfig(serviceName);
		_startLoging(); // Запускаем логирование сервиса

		// Определяем мастер-шаблон из конфига
		auto appIvyModulePtr = "appIvyModule" in this.config.rawConfig;
		auto appIvyMethodPtr = "appIvyMethod" in this.config.rawConfig;
		if( appIvyModulePtr && appIvyModulePtr.type == JSONType.string ) {
			_appIvyModule = appIvyModulePtr.str;
		}
		if( appIvyMethodPtr && appIvyMethodPtr.type == JSONType.string ) {
			_appIvyMethod = appIvyMethodPtr.str;
		}

		// Стартуем шаблонизатор для рендеринга страниц
		_ivyEngine = new WebtankIvyEngine([this.config.fileSystemPaths["siteIvyTemplates"]], this.log);

		// Анализируем манифесты webpack'а
		_webpackManifest = new WebpackManifest(this.config.fileSystemPaths["sitePublic"]);

		// Организуем маршрутизацию на сервисе
		_rootRouter = new HTTPRouter;
		_pageRouter = new URIPageRouter(pageURIPatternStr);
		_addPageRoutes();
		_rootRouter.addHandler(_pageRouter);

		_subscribeRoutingEvents();

		import webtank.net.http.handler.web_form_api_page_route: joinWebFormAPI;

		_rootRouter.joinWebFormAPI!getCompiledTemplate("/dyn/server/template");
	}

	this(string serviceName, string pageURIPatternStr, AuthClientController ac, AccessRightController rc)
	{
		import std.exception: enforce;
		enforce(ac, `Access controller expected`);
		enforce(rc, `Right controller expected`);
		this(serviceName, pageURIPatternStr);

		_accessController = ac;
		_rights = rc;
	}

	this(string serviceName, string pageURIPatternStr, bool isSecured)
	{
		import std.exception: enforce;
		enforce(isSecured, `Insecured view service kind in not implemented yet!`);

		this(serviceName, pageURIPatternStr);
		auto authNamePtr = ServiceRole.auth in this.config.serviceRoles;
		enforce(authNamePtr !is null && authNamePtr.length > 0, `Authentication service required in serviceRoles config option`);

		_accessController = new AuthClientController(this.config);
		_rights = new AccessRightController(
			new IvyAccessRuleFactory(this.ivyEngine),
			new RightRemoteSource(this.config, *authNamePtr, `accessRight.list`));
	}

	override void beforeRunServer() {
		_initAPIMixin();
	}

	void _addPageRoutes()
	{
		import webtank.ivy.service.view.uri_page_route: ViewServiceURIPageRoute;

		// Добавляем маршруты для страниц из конфигурационного файла
		foreach( entry; _config.pageRouting )
		{
			if( !entry.isValid )
				continue;
			_pageRouter.addHandler(new ViewServiceURIPageRoute(entry));
		}
	}

	IvyEngine ivyEngine() @property {
		return _ivyEngine;
	}

	override IServiceConfig config() @property {
		return _config;
	}

	override HTTPRouter rootRouter() @property {
		return _rootRouter;
	}

	URIPageRouter pageRouter() @property {
		return _pageRouter;
	}

	override LogWriter log() @property {
		return _loger;
	}

	override IvyViewServiceContext createContext(HTTPInput request, HTTPOutput response, IWebServer server) {
		return new IvyViewServiceContext(request, response, server);
	}

	private void _startLoging()
	{
		import webtank.common.log.writer: ThreadedLogWriter, FileLogWriter, LogLevel;
		
		import std.path: buildNormalizedPath;
		import std.exception: enforce;

		auto siteLogsParamPtr = "siteLogs" in this.config.fileSystemPaths;
		enforce(siteLogsParamPtr, "Failed to get logs directory!");
		if( !_loger ) {
			_loger = new ThreadedLogWriter(
				cast(shared) new FileLogWriter(
					buildNormalizedPath( (*siteLogsParamPtr), "view_service.log" ),
					LogLevel.info
				)
			);
		}
	}

	private void _subscribeRoutingEvents()
	{
		import webtank.net.utils: makeErrorMsg;
		import webtank.net.http.consts: HTTPStatus;
		_pageRouter.onError.join( (Exception ex, HTTPContext context)
		{
			auto messages = makeErrorMsg(ex);
			log.error(messages.details);
			_renderApp(context, IvyData(messages.userError));
			context.response.headers.statusCode = HTTPStatus.InternalServerError;
			return true; // Ошибка обработана
		});
	}

	override AuthClientController accessController() @property
	{
		auto ac = cast(AuthClientController) _accessController;
		enforce(ac !is null, `Expected AuthClientController`);
		return ac;
	}

	override AccessRightController rightController() @property
	{
		auto rc = cast(AccessRightController) _rights;
		enforce(rc !is null, `Expected AccessRightController`);
		return rc;
	}

	override void stop()
	{
		if( _loger ) {
			_loger.stop();
		}
	}

	/// Process request to render control (methodName) from ivy module (moduleName) inside app template
	void processViewRequest(IvyViewServiceContext ctx, string moduleName, string methodName)
	{
		import ivy.types.data.utils: errorToIvyData;

		auto globalParams = _prepareGlobalParams(ctx);
		SaveStateResult execRes = _renderContent(ctx, globalParams, moduleName, methodName);
		
		execRes.asyncResult.then(
			(IvyData content) {
				_renderApp(ctx, execRes.interp, content);
			},
			(Throwable error) {
				_renderApp(ctx, execRes.interp, errorToIvyData(error));
			});
	}

	/// Prepare global params for ivy interpreter calls
	IvyData[string] _prepareGlobalParams(HTTPContext context)
	{
		import webtank.net.std_json_rpc_client: getAllowedRequestHeaders;

		IvyData[string] ctx;
		ctx["user"] = new IvyUserIdentity(context.user);
		ctx["rights"] = new IvyUserRights(context.rights);
		ctx["vpaths"] = context.service.config.virtualPaths;
		ctx["forwardHTTPHeaders"] = context.getAllowedRequestHeaders();
		ctx["endpoints"] = context.service.config.endpoints;

		return [
			"context": IvyData(ctx)
		];
	}

	/// Render content of page
	SaveStateResult _renderContent(
		HTTPContext ctx,
		ref IvyData[string] globalParams,
		string moduleName,
		string methodName
	) {
		AsyncResult asyncRes = new AsyncResult();

		SaveStateResult moduleExecRes = this.ivyEngine.runModule(moduleName, _prepareGlobalParams(ctx));
		auto interp = moduleExecRes.interp;

		moduleExecRes.asyncResult.then((IvyData modRes) {
			// Module executed successfuly, then call method
			auto methodCallable = interp.asCallable(modRes.execFrame.getValue(methodName));

			IvyData[string] params;
			// We shal get method symbol from current module scope
			// Then try to deserialize and pass parameters from web-form to method args
			_addViewParams(params, ctx.request.form, methodCallable.symbol);
			// Run method with params
			interp.execCallable(methodCallable, params).then(asyncRes);
		}, &asyncRes.reject);

		return SaveStateResult(interp, asyncRes);
	}

	void _renderApp(HTTPContext ctx, IvyData content) {
		_renderApp(ctx, this.ivyEngine.makeInterp(_prepareGlobalParams(ctx)), content);
	}

	void _renderApp(
		HTTPContext ctx,
		Interpreter interp,
		IvyData content
	) {
		import std.range: empty;
		import std.string: toLower;

		import ivy.types.data.utils: errorToIvyData;

		// Если не задан мастер-шаблон, либо установлена опция вывода без мастер-шаблона, то выводим без мастер-шаблона. В чем, собственно, логика есть...
		if( _appIvyModule.empty || ctx.request.queryForm.get("appTemplate", null).toLower() == "no" )
		{
			_renderResultToResponse(ctx, content, interp);
			return;
		}

		_renderAppTemplate(ctx, interp, content).then(
			(IvyData appContent) {
				_renderResultToResponse(ctx, appContent, interp);
			},
			(Throwable error) {
				_renderResultToResponse(ctx, errorToIvyData(error), interp);
			});
	}

	AsyncResult _renderAppTemplate(
		HTTPContext ctx,
		Interpreter interp,
		IvyData content
	) {
		import ivy.types.callable_object: CallableObject;
		import ivy.types.data.iface.class_node: IClassNode;

		AsyncResult asyncRes = new AsyncResult();

		auto appModuleExecRes = this.ivyEngine.runModule(_appIvyModule, interp);

		appModuleExecRes.asyncResult.then((IvyData modRes) {
			auto methodCallable = interp.asCallable(modRes.execFrame.getValue(_appIvyMethod));

			// Run app control constructor with params
			interp.execCallable(methodCallable, _prepareAppParams(ctx, content)).then(
				(IvyData appContent) {
					// If app content is a class then try to run render method on it
					if( appContent.type == IvyDataType.ClassNode ) {
						interp.execClassMethod(appContent.classNode, DEFAULT_CLASS_METHOD).then(asyncRes);
					} else {
						asyncRes.resolve(appContent);
					}
				},
				&asyncRes.reject);
		}, &asyncRes.reject);

		return asyncRes;
	}

	IvyData[string] _prepareAppParams(HTTPContext ctx, IvyData content)
	{
		import std.algorithm: splitter, map, filter;
		import std.string: strip;
		import std.array: array;

		import webtank.security.right.source_method: getAccessRightList;
		import webtank.common.std_json.to: toStdJSON;
		import ivy.types.data.conv.std_to_ivy_json: toIvyJSON;
		import ivy.types.data.iface.class_node: IClassNode;

		auto rights = getAccessRightList(rightController.rightSource);
		IvyData ivyRights;
		if( ctx.user.isAuthenticated() ) {
			auto jRights = rights.toStdJSON();
			ivyRights = jRights.toIvyJSON();
		}
		
		string[] accessRoles = ctx.user.data.get("accessRoles", null)
			.splitter(';')
			.map!(strip)
			.filter!((it) => it.length)
			.array;

		string webpackLib;
		if( content.type == IvyDataType.ClassNode )
		{
			IClassNode control = content.classNode;
			// Get JavaScript module name for control
			string jsModuleName = control.__getAttr__("moduleName").str;
			// Get webpack library name for control
			webpackLib = this._webpackManifest.getLibPath(jsModuleName);
		}

		return [
			"content": content,
			"userRightData": IvyData([
				"user": IvyData([
					"id": IvyData(ctx.user.id),
					"name": IvyData(ctx.user.name),
					"accessRoles": IvyData(accessRoles),
					"sessionId": (ctx.user.isAuthenticated()? IvyData("dummy"): IvyData())
				]),
				"right": ivyRights
			]),
			"webpackLib": IvyData(webpackLib)
		];
	}

	private void _renderResultToResponse(HTTPContext ctx, IvyData content, Interpreter interp)
	{
		import ivy.types.data.render: renderDataNode, DataRenderType;

		// Если есть "мусор" в буфере вывода, то попытаемся его убрать
		ctx.response.tryClearBody();

		HTTPOutput response = ctx.response;
		renderDataNode!(DataRenderType.HTML)(response, content, interp);
	}

	static void _addViewParams(ref IvyData[string] params, IFormData form, ICallableSymbol symb)
	{
		DirAttr[] attrs = symb.attrs;
		// Converting allowed parameters from web form to ivy method params dictionary
		foreach( attr; attrs )
		{
			auto valPtr = attr.name in form;
			
			if( valPtr is null )
				continue;
			IvyData val = _convViewParam(*valPtr, attr);
			if( val.type == IvyDataType.Undef )
				continue;
			params[attr.name] = val;
		}
	}

	static IvyData _convViewParam(string val, const ref DirAttr attr)
	{
		import std.range: empty;
		import webtank.common.conv: conv;
		import std.algorithm: canFind;
		import ivy.types.symbol.consts: IvyAttrType;

		// For string or `any` pass `as is`
		if( attr.typeName.empty || [IvyAttrType.Any, IvyAttrType.Str].canFind(attr.typeName) )
			return IvyData(val);

		// Just ignore empty context values for non-string types
		if( val.empty )
			return IvyData();

		// Create white list of type that we can deserialize
		switch( attr.typeName )
		{
			case IvyAttrType.Bool: return IvyData(conv!bool(val));
			case IvyAttrType.Int: return IvyData(conv!long(val));
			case IvyAttrType.Float: return IvyData(conv!double(val));
			default: break;
		}
		return IvyData();
	}

	static JSONValue getCompiledTemplate(IvyViewServiceContext ctx) {
		return ctx.service.ivyEngine.serializeModule(ctx.request.form[`moduleName`]);
	}
}

