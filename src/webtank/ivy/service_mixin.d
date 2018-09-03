module webtank.ivy.service_mixin;

interface IIvyServiceMixin
{
	import webtank.net.http.context: HTTPContext;
	import ivy.interpreter.data_node: IvyData;
	import ivy.programme: ExecutableProgramme;
	import ivy.interpreter.interpreter: Interpreter;

	ExecutableProgramme getIvyModule(string moduleName);
	IvyData runIvyModule(string moduleName, HTTPContext ctx, IvyData dataDict = IvyData.init);
	IvyData runIvyModule(string moduleName, IvyData dataDict = IvyData.init);
	Interpreter runIvySaveState(string moduleName, HTTPContext ctx, IvyData dataDict = IvyData.init);
	Interpreter runIvySaveState(string moduleName, IvyData dataDict = IvyData.init);

}

mixin template IvyServiceMixin()
{
	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.output: HTTPOutput;
	import webtank.common.loger: Loger, LogEvent, LogEventType, ThreadedLoger, FileLoger, LogLevel;
	import webtank.ivy.user: IvyUserIdentity;
	import webtank.ivy.rights: IvyUserRights;

	import ivy.programme: ExecutableProgramme, ProgrammeCache, IvyConfig;
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.interpreter.data_node: IvyData;
	import ivy.common: LogInfo, LogInfoType;
	import ivy.interpreter.data_node_render: renderDataNode, DataRenderType;

	debug enum bool useTemplatesCache = false;
	else enum bool useTemplatesCache = true;

public:
	override ExecutableProgramme getIvyModule(string moduleName)
	{
		import std.exception: enforce;
		enforce(_templateCache !is null, `ViewService template cache is null!!!`);
		return _templateCache.getByModuleName(moduleName);
	}

	private IvyData[string] _prepareExtraGlobals(HTTPContext ctx)
	{
		import std.exception: enforce;
		enforce(ctx !is null, `Expected context!`);
		IvyData[string] extraGlobals;
		extraGlobals[`userRights`] = new IvyUserRights(ctx.rights);
		extraGlobals[`userIdentity`] = new IvyUserIdentity(ctx.user);
		extraGlobals[`vpaths`] = ctx.service.virtualPaths;
		return extraGlobals;
	}

	override IvyData runIvyModule(string moduleName, HTTPContext ctx, IvyData dataDict = IvyData.init){
		return getIvyModule(moduleName).run(dataDict, _prepareExtraGlobals(ctx));
	}

	override IvyData runIvyModule(string moduleName, IvyData dataDict) {
		return getIvyModule(moduleName).run(dataDict);
	}

	override Interpreter runIvySaveState(string moduleName, HTTPContext ctx, IvyData dataDict = IvyData.init) {
		return getIvyModule(moduleName).runSaveState(dataDict, _prepareExtraGlobals(ctx));
	}

	override Interpreter runIvySaveState(string moduleName, IvyData dataDict = IvyData.init) {
		return getIvyModule(moduleName).runSaveState(dataDict);
	}

	void renderResult(IvyData content, HTTPContext context)
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
	ProgrammeCache!(useTemplatesCache) _templateCache;

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

		_templateCache = new ProgrammeCache!(useTemplatesCache)(ivyConfig);
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