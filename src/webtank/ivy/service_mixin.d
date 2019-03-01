module webtank.ivy.service_mixin;

interface IIvyServiceMixin
{
	import webtank.net.http.context: HTTPContext;
	import ivy.interpreter.data_node: IvyData;
	import ivy.engine: IvyEngine;

	IvyEngine ivyEngine() @property;

	void renderResult(IvyData content, HTTPContext context);
}

mixin template IvyServiceMixin()
{
	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.output: HTTPOutput;
	import webtank.common.loger: Loger, LogEvent, LogEventType, ThreadedLoger, FileLoger, LogLevel;
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
	IvyEngine ivyEngine() @property
	{
		import std.exception: enforce;
		enforce(_ivyEngine, `Ivy engine is not initialized`);
		return _ivyEngine;
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
		if( _ivyEngine )
			return; //Already initialized
		
		import std.exception: enforce;
		enforce("siteIvyTemplates" in _fileSystemPaths, `Failed to get path to site Ivy templates!`);
		IvyConfig ivyConfig;
		ivyConfig.importPaths = [_fileSystemPaths["siteIvyTemplates"]];
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

import webtank.net.http.context: HTTPContext;
import ivy.interpreter.data_node: IvyData;
import webtank.net.http.handler: IHTTPHandler, HTTPHandlingResult;
class ViewServiceURIPageRoute: IHTTPHandler
{
	import webtank.net.service.config: RoutingConfigEntry;
	import webtank.net.uri_pattern;
	import webtank.ivy.rpc_client: remoteCallWebForm;
	import webtank.net.std_json_rpc_client: RemoteCallInfo, getAllowedRequestHeaders;
	import webtank.net.uri: URI;
protected:
	RoutingConfigEntry _entry;
	URIPattern _uriPattern;


public:
	this(RoutingConfigEntry entry)
	{
		import std.exception: enforce;
		_entry = entry;
		_uriPattern = new URIPattern(entry.pageURI);
	}

	static string defaultBackend(HTTPContext ctx) @property
	{
		import std.exception: enforce;
		import std.json: JSON_TYPE;
		auto backendNamePtr = `backendService` in ctx.service.rawConfig;
		enforce(backendNamePtr, `Expected default backend service name in config`);
		enforce(backendNamePtr.type == JSON_TYPE.STRING, `Backend service name must be a string`);
		string backendName = backendNamePtr.str;
		enforce(backendName.length > 0, `Backend service name must not be empty`);
		return backendName;
	}

	override HTTPHandlingResult processRequest(HTTPContext context)
	{
		import std.exception: enforce;
		import std.uni: asLowerCase;
		import std.algorithm: equal;
		import std.range: empty;

		if( _entry.HTTPMethod.length > 0 )
		{
			// Filter by HTTP-method if it was specified
			if( !equal(context.request.method.asLowerCase, _entry.HTTPMethod.asLowerCase) )
				return HTTPHandlingResult.mismatched;
		}

		auto pageURIData = _uriPattern.match(context.request.uri.path);
		if( !pageURIData.isMatched )
			return HTTPHandlingResult.mismatched;

		IIvyServiceMixin ivyService = cast(IIvyServiceMixin) context.service;
		enforce(ivyService, `ViewServiceURIPageRoute can only work with IIvyServiceMixin instances`);
		context.request.requestURIMatch = pageURIData;

		IvyData methodParams;
		bool isError = false;
		if( !_entry.apiURI.empty )
		{
			URI apiURI = URI(_entry.apiURI);

			if( apiURI.host.empty || apiURI.scheme.empty )
			{
				// If backend service name is specified in routing config then use it
				// If it is not specified use default backend for current service
				string service = _entry.service.empty? defaultBackend(context): _entry.service;

				// If vpath name is specified the use it
				// If it is not specified use default constant
				string endpoint = _entry.endpoint.empty? `siteWebFormAPI`: _entry.endpoint;

				// Get endpoint URI from service config using service name and vpath name
				URI epURI = URI(context.service.endpoint(service, endpoint));

				if( apiURI.host.empty ) {
					apiURI.scheme = epURI.scheme;
				}
				if( apiURI.rawAuthority ) {
					apiURI.rawAuthority = epURI.rawAuthority;
				}

				import std.path: buildNormalizedPath;
				apiURI.path = buildNormalizedPath(epURI.path, apiURI.path);
			}

			if( apiURI.rawQuery.empty )
			{
				// Change response with what is passed by user
				apiURI.rawQuery = context.request.requestURI.rawQuery;
			}

			enforce(!apiURI.scheme.empty, `Failed to determine scheme for request`);
			enforce(!apiURI.host.empty, `Failed to determine remote host for request`);
			enforce(apiURI.port != 0, `Failed to determine remote port for request`);

			RemoteCallInfo callInfo = RemoteCallInfo(apiURI.toRawString(), getAllowedRequestHeaders(context));
			string HTTPMethod = (!_entry.HTTPMethod.empty? _entry.HTTPMethod: context.request.method);

			try {
				methodParams = remoteCallWebForm!IvyData(callInfo, HTTPMethod, context.request.messageBody);
			} catch( Exception ex ) {
				// Нужно передать ошибку в шаблон
				isError = true;
				methodParams = IvyData([
					`errorMsg`: ex.msg
				]);
			}
			
		}

		void renderResult(IvyData res) {
			ivyService.renderResult(res, context);
		}

		void renderError(Throwable error) {
			import ivy.interpreter.data_node: errorToIvyData;
			ivyService.renderResult(errorToIvyData(error), context);
			throw error;
		}

		// Если ошибка и есть спец. Ivy модуль/ метод для обработки в конфигурации, то используем его
		// Если же нет спец. модуля/ метода, то передаем в общий модуль/ метод
		string ivyModule = (isError && !_entry.ivyModuleError.empty)? _entry.ivyModuleError: _entry.ivyModule;
		string ivyMethod = (isError && !_entry.ivyMethodError.empty)? _entry.ivyMethodError: _entry.ivyMethod;

		// Добавляем некотрые параметры по умолчанию
		import std.algorithm: canFind;
		if( !_entry.ivyParams.canFind(`instanceName`) ) {
			_entry.ivyParams ~= `instanceName`;
		}
		
		// Пробрасываем разрешенные параметры из web-формы в интерфейс
		foreach( parName; _entry.ivyParams )
		{
			if( auto parValPtr = parName in context.request.form ) {
				if( parName in methodParams )
					continue; // Не перезаписываем поля переданные нам backend-сервером
				methodParams[parName] = *parValPtr;
			}
		}

		if( !ivyModule.empty )
		{
			import ivy.programme: ExecutableProgramme;
			ExecutableProgramme ivyProg = ivyService.ivyEngine.getByModuleName(ivyModule);
			if( !ivyMethod.empty )
			{
				ivyProg.runMethod(ivyMethod, methodParams, prepareIvyGlobals(context))
					.then(&renderResult, &renderError);
			}
			else
			{
				ivyProg.run(IvyData(), prepareIvyGlobals(context))
					.then(&renderResult, &renderError);
			}
		} else {
			// Шаблон не указан - просто выводим сам результат вызова
			ivyService.renderResult(methodParams, context);
		}

		return HTTPHandlingResult.handled; // Запрос обработан
	}
}

IvyData[string] prepareIvyGlobals(HTTPContext ctx)
{
	import std.exception: enforce;
	import webtank.ivy.user: IvyUserIdentity;
	import webtank.ivy.rights: IvyUserRights;
	import webtank.net.std_json_rpc_client: getAllowedRequestHeaders;
	enforce(ctx !is null, `Expected context!`);
	IvyData[string] extraGlobals;
	extraGlobals[`userRights`] = new IvyUserRights(ctx.rights);
	extraGlobals[`userIdentity`] = new IvyUserIdentity(ctx.user);
	extraGlobals[`vpaths`] = ctx.service.virtualPaths;
	extraGlobals[`forwardHTTPHeaders`] = ctx.getAllowedRequestHeaders();
	return extraGlobals;
}