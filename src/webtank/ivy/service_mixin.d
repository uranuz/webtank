module webtank.ivy.service_mixin;

interface IIvyServiceMixin
{
	import webtank.net.http.context: HTTPContext;
	import ivy.interpreter.data_node: IvyData;
	import ivy.programme: ExecutableProgramme, SaveStateResult;
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.interpreter.async_result: AsyncResult;

	ExecutableProgramme getIvyModule(string moduleName);

	AsyncResult runIvyModule(string moduleName, HTTPContext ctx, IvyData dataDict = IvyData.init);
	AsyncResult runIvyModule(string moduleName, IvyData dataDict);

	IvyData runIvyModuleSync(string moduleName, HTTPContext ctx, IvyData dataDict = IvyData.init);
	IvyData runIvyModuleSync(string moduleName, IvyData dataDict);

	AsyncResult runIvyMethod(
		string moduleName,
		string methodName,
		HTTPContext ctx,
		IvyData dataDict = IvyData.init
	);
	AsyncResult runIvyMethod(
		string moduleName,
		string methodName,
		IvyData dataDict = IvyData.init
	);

	IvyData runIvyMethodSync(
		string moduleName,
		string methodName,
		HTTPContext ctx,
		IvyData dataDict = IvyData.init
	);
	IvyData runIvyMethodSync(
		string moduleName,
		string methodName,
		IvyData dataDict = IvyData.init
	);

	void renderResult(IvyData content, HTTPContext context);
}

mixin template IvyServiceMixin()
{
	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.output: HTTPOutput;
	import webtank.common.loger: Loger, LogEvent, LogEventType, ThreadedLoger, FileLoger, LogLevel;
	import webtank.ivy.user: IvyUserIdentity;
	import webtank.ivy.rights: IvyUserRights;
	import webtank.net.std_json_rpc_client: getAllowedRequestHeaders;
	import webtank.ivy.remote_call: RemoteCallInterpreter;

	import ivy.engine: IvyEngine;
	import ivy.engine_config: IvyConfig;
	import ivy.programme: ExecutableProgramme, SaveStateResult;
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.interpreter.data_node: IvyData;
	import ivy.common: LogInfo, LogInfoType;
	import ivy.interpreter.data_node_render: renderDataNode, DataRenderType;
	import ivy.interpreter.directive.standard_factory: makeStandardInterpreterDirFactory;
	import ivy.interpreter.async_result: AsyncResult;

public:
	override ExecutableProgramme getIvyModule(string moduleName)
	{
		import std.exception: enforce;
		enforce(_ivyEngine !is null, `ViewService template cache is null!!!`);
		return _ivyEngine.getByModuleName(moduleName);
	}

	private IvyData[string] _prepareExtraGlobals(HTTPContext ctx)
	{
		import std.exception: enforce;
		enforce(ctx !is null, `Expected context!`);
		IvyData[string] extraGlobals;
		extraGlobals[`userRights`] = new IvyUserRights(ctx.rights);
		extraGlobals[`userIdentity`] = new IvyUserIdentity(ctx.user);
		extraGlobals[`vpaths`] = ctx.service.virtualPaths;
		extraGlobals[`forwardHTTPHeaders`] = ctx.getAllowedRequestHeaders();
		return extraGlobals;
	}

	override AsyncResult runIvyModule(string moduleName, HTTPContext ctx, IvyData dataDict = IvyData.init) {
		return getIvyModule(moduleName).run(dataDict, _prepareExtraGlobals(ctx));
	}

	override AsyncResult runIvyModule(string moduleName, IvyData dataDict) {
		return getIvyModule(moduleName).run(dataDict);
	}

	override IvyData runIvyModuleSync(string moduleName, HTTPContext ctx, IvyData dataDict = IvyData.init) {
		return getIvyModule(moduleName).runSync(dataDict, _prepareExtraGlobals(ctx));
	}

	override IvyData runIvyModuleSync(string moduleName, IvyData dataDict) {
		return getIvyModule(moduleName).runSync(dataDict);
	}

	override AsyncResult runIvyMethod(
		string moduleName,
		string methodName,
		HTTPContext ctx,
		IvyData dataDict = IvyData.init
	) {
		return getIvyModule(moduleName).runMethod(methodName, dataDict, _prepareExtraGlobals(ctx));
	}

	override AsyncResult runIvyMethod(
		string moduleName,
		string methodName,
		IvyData dataDict = IvyData.init
	) {
		return getIvyModule(moduleName).runMethod(methodName, dataDict);
	}

	override IvyData runIvyMethodSync(
		string moduleName,
		string methodName,
		HTTPContext ctx,
		IvyData dataDict = IvyData.init
	) {
		return getIvyModule(moduleName).runMethodSync(methodName, dataDict, _prepareExtraGlobals(ctx));
	}

	override IvyData runIvyMethodSync(
		string moduleName,
		string methodName,
		IvyData dataDict = IvyData.init
	) {
		return getIvyModule(moduleName).runMethodSync(methodName, dataDict);
	}

	override void renderResult(IvyData content, HTTPContext context)
	{
		static struct OutRange
		{
			private HTTPOutput _resp;
			void put(T)(T data) {
				import std.conv: text;
				_resp.write(data.text);
			}
		}

		renderDataNode!(DataRenderType.HTML)(content, OutRange(context.response));
	}


private:
	Loger _ivyLoger;
	IvyEngine _ivyEngine;

	void _initTemplateCache()
	{
		assert( "siteIvyTemplates" in _fileSystemPaths, `Failed to get path to site Ivy templates!` );
		IvyConfig ivyConfig;
		ivyConfig.importPaths = [ _fileSystemPaths["siteIvyTemplates"] ];
		ivyConfig.fileExtension = ".ivy";

		// Направляем логирование шаблонизатора в файл
		ivyConfig.parserLoger = &_ivyLogerMethod;
		ivyConfig.compilerLoger = &_ivyLogerMethod;
		ivyConfig.interpreterLoger = &_ivyLogerMethod;

		ivyConfig.directiveFactory = makeStandardInterpreterDirFactory();
		ivyConfig.directiveFactory.add(new RemoteCallInterpreter);

		debug ivyConfig.clearCache = true;

		_ivyEngine = new IvyEngine(ivyConfig);
	}

	void _startIvyLogging()
	{
		import std.path: buildNormalizedPath;
		import std.exception: enforce;

		enforce("siteLogs" in _fileSystemPaths, `Failed to get logs directory!`);
		if( !_ivyLoger ) {
			_ivyLoger = new ThreadedLoger(
				cast(shared) new FileLoger(
					buildNormalizedPath( _fileSystemPaths["siteLogs"], "ivy.log" ),
					LogLevel.dbg
				)
			);
		}
	}

	void _stopIvyLogging()
	{
		if( _ivyLoger ) {
			_ivyLoger.stop();
		}
	}

	// Метод перенаправляющий логи шаблонизатора в файл
	void _ivyLogerMethod(LogInfo logInfo)
	{
		import std.datetime;
		import std.conv: text;
		import std.exception: enforce;
		enforce(_ivyLoger, `_ivyLoger is null`);

		LogEvent wtLogEvent;
		final switch(logInfo.type) {
			case LogInfoType.info: wtLogEvent.type = LogEventType.dbg; break;
			case LogInfoType.warn: wtLogEvent.type = LogEventType.warn; break;
			case LogInfoType.error: wtLogEvent.type = LogEventType.error; break;
			case LogInfoType.internalError: wtLogEvent.type = LogEventType.crit; break;
		}

		wtLogEvent.text ~= logInfo.msg;
		wtLogEvent.prettyFuncName = logInfo.sourceFuncName;
		wtLogEvent.file = logInfo.sourceFileName;
		wtLogEvent.line = logInfo.sourceLine;
		wtLogEvent.timestamp = std.datetime.Clock.currTime();

		_ivyLoger.writeEvent(wtLogEvent);
	}
}

import webtank.net.http.handler: IHTTPHandler, HTTPHandlingResult;
class ViewServiceURIPageRoute: IHTTPHandler
{
	import webtank.net.service.config: RoutingConfigEntry;
	import webtank.net.uri_pattern;
	import webtank.net.http.context: HTTPContext;

	import ivy.interpreter.data_node: IvyData;
protected:
	RoutingConfigEntry _entry;
	URIPattern _uriPattern;


public:
	this(RoutingConfigEntry entry) {
		_entry = entry;
		_uriPattern = new URIPattern(entry.pageURI);
	}


	override HTTPHandlingResult processRequest(HTTPContext context)
	{
		import std.exception: enforce;
		auto pageURIData = _uriPattern.match(context.request.uri.path);
		if( !pageURIData.isMatched )
			return HTTPHandlingResult.mismatched;

		IIvyServiceMixin ivyService = cast(IIvyServiceMixin) context.service;
		enforce(ivyService, `ViewServiceURIPageRoute can only work with IIvyServiceMixin instances`);
		context.request.requestURIMatch = pageURIData;
		
		if( _entry.ivyMethod.length > 0 )
		{
			ivyService.runIvyMethod(
				_entry.ivyModule, _entry.ivyMethod, context
			).then(
				(IvyData res) {
					ivyService.renderResult(res, context);
				},
				(IvyData res) {
					ivyService.renderResult(res, context);
				},
			);
		}
		else
		{
			ivyService.runIvyModule(
				_entry.ivyModule, context
			).then(
				(IvyData res) {
					ivyService.renderResult(res, context);
				},
				(IvyData res) {
					ivyService.renderResult(res, context);
				},
			);
		}
		return HTTPHandlingResult.handled; // Запрос обработан
	}

}