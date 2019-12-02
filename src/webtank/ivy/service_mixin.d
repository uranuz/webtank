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
	import webtank.ivy.directive.standard_factory: makeStandardInterpreterDirFactory;

	import ivy.engine: IvyEngine;
	import ivy.engine_config: IvyConfig;
	import ivy.programme: ExecutableProgramme, SaveStateResult;
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.interpreter.data_node: IvyData;
	import ivy.common: LogInfo, LogInfoType;
	import ivy.interpreter.data_node_render: renderDataNode, DataRenderType;
	
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
import ivy.interpreter.data_node: IvyData, IvyDataType;
import webtank.net.http.handler.iface: IHTTPHandler, HTTPHandlingResult;
class ViewServiceURIPageRoute: IHTTPHandler
{
	import webtank.net.service.config: RoutingConfigEntry;
	import webtank.net.uri_pattern;
	import webtank.ivy.rpc_client: remoteCallWebForm;
	import ivy.directive_stuff: DirValueAttr;
	import webtank.net.std_json_rpc_client: RemoteCallInfo, getAllowedRequestHeaders;
	import webtank.net.uri: URI;

	import std.exception: enforce;
	import std.range: empty;
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
		import std.json: JSONType;
		auto backendNamePtr = `backendService` in ctx.service.rawConfig;
		enforce(backendNamePtr, `Expected default backend service name in config`);
		enforce(backendNamePtr.type == JSONType.string, `Backend service name must be a string`);
		string backendName = backendNamePtr.str;
		enforce(backendName.length > 0, `Backend service name must not be empty`);
		return backendName;
	}

	static IIvyServiceMixin _getServiceMixin(HTTPContext context)
	{
		IIvyServiceMixin ivyService = cast(IIvyServiceMixin) context.service;
		enforce(ivyService, `ViewServiceURIPageRoute can only work with IIvyServiceMixin instances`);
		return ivyService;
	}

	import ivy.interpreter.data_node: errorToIvyData;

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

		auto uriMatchData = _uriPattern.match(context.request.uri.path);
		if( !uriMatchData.isMatched )
			return HTTPHandlingResult.mismatched;

		enforce(!_entry.ivyModule.empty, `Ivy module name required`);
		enforce(!_entry.ivyMethod.empty, `Ivy method name required`);

		context.request.requestURIMatch = uriMatchData;

		import ivy.programme: ExecutableProgramme;
		ExecutableProgramme ivyProg = _getServiceMixin(context).ivyEngine.getByModuleName(_entry.ivyModule);
		auto modRes = ivyProg.runSaveState(IvyData(), prepareIvyGlobals(context));

		modRes.asyncResult.then((IvyData) {
			_onIvyModule_init(context, modRes.interp);
		}, (Throwable error) {
			// Модуль загрузить не удалось. Пичально
			_getServiceMixin(context).renderResult(errorToIvyData(error), context);
			throw error;
		});

		return HTTPHandlingResult.handled; // Запрос обработан
	}

	import ivy.interpreter.interpreter: Interpreter;

	void _onIvyModule_init(HTTPContext context, Interpreter interp)
	{
		DirValueAttr[string] dirAttrs = interp.getDirAttrs(_entry.ivyMethod);
		auto callOpts = _getCallOpts(dirAttrs, context);
		//context.junk[`ivyModule`] = _entry.ivyModule.empty;
		//context.junk[`ivyMethod`] = _entry.ivyMethod;
		if( auto moduleNamePtr = `moduleName` in dirAttrs )
		{
			enforce(
				moduleNamePtr && moduleNamePtr.defaultValue.type == IvyDataType.String,
				`Expected non-empty string as "moduleName" attribute`
			);
			context.junk[`moduleName`] = moduleNamePtr.defaultValue.str;
		}

		IvyData methodParams;
		Exception callError = null;
		if( !callOpts.address.empty )
		{
			try {
				methodParams = remoteCallWebForm!IvyData(
					callOpts.address,
					callOpts.HTTPMethod,
					callOpts.HTTPHeaders,
					context.request.messageBody);
			} catch( Exception ex ) {
				// Сохраняем информацию об ошибке
				callError = ex;
			}
		}

		void renderResult(IvyData res) {
			_getServiceMixin(context).renderResult(res, context);
		}

		void renderError(Throwable error) {
			_getServiceMixin(context).renderResult(errorToIvyData(error), context);
			throw error;
		}

		if( callError is null )
		{
			_addViewParams(context, methodParams, dirAttrs);
			interp.runModuleDirective(_entry.ivyMethod, methodParams)
				.then(&renderResult, &renderError);
		}
		else
		{
			// Есть ошибка вызова метода
			auto errorOpts = _getErrorOpts(dirAttrs);
			if( !errorOpts.ivyModuleError.empty && !errorOpts.ivyMethodError.empty )
			{
				IvyData errorParams = errorToIvyData(callError);
				_addViewParams(context, errorParams, dirAttrs);
				_getServiceMixin(context)
					.ivyEngine
					.getByModuleName(_entry.ivyModule)
					.runMethod(_entry.ivyMethod, errorParams, prepareIvyGlobals(context))
					.then(&renderResult, &renderError);
			} else {
				// Шаблон ошибки не задан, то вываливаем ошибку как есть
				renderError(callError);
			}
		}
	}

	// Добавляем параметры, которые нужно передать напрямую в шаблон
	void _addViewParams(HTTPContext context, ref IvyData params, DirValueAttr[string] dirAttrs)
	{
		import webtank.common.conv: conv;
		import std.range: empty;
		import std.algorithm: canFind;

		// Пробрасываем разрешенные параметры из web-формы в интерфейс
		foreach( attrName, dirAttr; dirAttrs )
		{
			if( auto valPtr = attrName in context.request.form )
			{
				if( attrName in params )
					continue; // Не перезаписываем поля, переданные backend-сервером

				if( dirAttr.typeName.empty || [`str`, `any`].canFind(dirAttr.typeName) ) {
					// For string or `any` pass `as is`
					params[attrName] = *valPtr;
					continue;
				}

				if( (*valPtr).empty ) {
					continue; // Just ignore empty context values for non-string types
				}

				// Create white list of type that we can deserialize
				switch( dirAttr.typeName )
				{
					case `bool`: {
						params[attrName] = conv!bool(*valPtr);
						break;
					}
					case `int`: {
						params[attrName] = conv!long(*valPtr);
						break;
					}
					case `float`: {
						params[attrName] = conv!double(*valPtr);
						break;
					}
					default:
						continue; // We don't want to fail with wrong param from interface for now
				}
			}
		}
	}

	import std.typecons: Tuple;
	Tuple!(
		string, `address`,
		string, `HTTPMethod`,
		string[string], `HTTPHeaders`
	)
	_getCallOpts(DirValueAttr[string] dirAttrs, HTTPContext context)
	{
		import std.algorithm: canFind;

		string defaultRequestURI;
		if( auto reqUriPtr = `requestURI` in dirAttrs )
		{
			enforce([
					IvyDataType.Undef, IvyDataType.Null, IvyDataType.String
				].canFind(reqUriPtr.defaultValue.type),
				`Request URI attrubute expected to be string or empty`);
			
			if( reqUriPtr.defaultValue.type == IvyDataType.String ) {
				defaultRequestURI = reqUriPtr.defaultValue.str;
			}
		}

		string requestURIStr = _entry.requestURI.empty? defaultRequestURI: _entry.requestURI;
		if( requestURIStr.empty ) {
			return typeof(return)(); // Nowhere to request
		}

		URI requestURI = URI(requestURIStr);

		if( requestURI.host.empty || requestURI.scheme.empty )
		{
			// If backend service name is specified in routing config then use it
			// If it is not specified use default backend for current service
			string service = _entry.service.empty? defaultBackend(context): _entry.service;

			// If vpath name is specified the use it
			// If it is not specified use default constant
			string endpoint = _entry.endpoint.empty? `siteWebFormAPI`: _entry.endpoint;

			// Get endpoint URI from service config using service name and vpath name
			URI epURI = URI(context.service.endpoint(service, endpoint));

			if( requestURI.host.empty ) {
				requestURI.scheme = epURI.scheme;
			}
			if( requestURI.rawAuthority ) {
				requestURI.rawAuthority = epURI.rawAuthority;
			}

			import std.path: buildNormalizedPath;
			requestURI.path = buildNormalizedPath(epURI.path, requestURI.path);
		}

		if( requestURI.rawQuery.empty )
		{
			// Change query string part with what is passed by user
			requestURI.rawQuery = context.request.requestURI.rawQuery;
		}

		string HTTPMethod = (!_entry.HTTPMethod.empty? _entry.HTTPMethod: context.request.method);

		enforce(!requestURI.scheme.empty, `Failed to determine scheme for request`);
		enforce(!requestURI.host.empty, `Failed to determine remote host for request`);
		enforce(requestURI.port != 0, `Failed to determine remote port for request`);
		enforce(!HTTPMethod.empty, `Failed to determine HTTP method for request`);

		return typeof(return)(requestURI.toRawString(), HTTPMethod, getAllowedRequestHeaders(context));
	}

	Tuple!(
		string, `ivyModuleError`,
		string, `ivyMethodError`
	)
	_getErrorOpts(DirValueAttr[string] dirAttrs)
	{
		
		typeof(return) res;
		if( !_entry.ivyModuleError.empty ) {
			res.ivyModuleError = _entry.ivyModuleError;
		}
		if( auto modErrorPtr = `ivyModuleError` in dirAttrs )
		{
			auto defVal = modErrorPtr.defaultValue;
			if( defVal.type == IvyDataType.String && !defVal.str.empty ) {
				res.ivyModuleError = defVal.str;
			}
		}

		if( !_entry.ivyMethodError.empty ) {
			res.ivyMethodError = _entry.ivyMethodError;
		}
		if( auto methErrorPtr = `ivyMethodError` in dirAttrs )
		{
			auto defVal = methErrorPtr.defaultValue;
			if( defVal.type == IvyDataType.String && !defVal.str.empty ) {
				res.ivyMethodError = defVal.str;
			}
		}
		return res;
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