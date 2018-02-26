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

import ivy;
import ivy.interpreter.data_node_render: renderDataNode, DataRenderType;


class IvyViewService: IWebService
{
	mixin ServiceConfigImpl;
protected:
	import std.json: JSONValue;
	debug enum bool useTemplatesCache = false;
	else enum bool useTemplatesCache = true;

	string _serviceName;
	HTTPRouter _rootRouter;
	URIPageRouter _pageRouter;
	Loger _loger;
	Loger _ivyLoger;
	ProgrammeCache!(useTemplatesCache) _templateCache;

	IAccessController _accessController;

public:
	this(string serviceName, IAccessController accessController, string pageURIPatternStr)
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

	ProgrammeCache!(useTemplatesCache) templateCache() @property {
		return _templateCache;
	}

	private void _startLoging()
	{
		import std.path: buildNormalizedPath;

		assert( "siteLogs" in _fileSystemPaths, `Failed to get logs directory!` );
		if( !_loger ) {
			_loger = new ThreadedLoger(
				cast(shared) new FileLoger(
					buildNormalizedPath( _fileSystemPaths["siteLogs"], "view_service.log" ),
					LogLevel.info
				)
			);
		}

		if( !_ivyLoger ) {
			_ivyLoger = new ThreadedLoger(
				cast(shared) new FileLoger(
					buildNormalizedPath( _fileSystemPaths["siteLogs"], "ivy.log" ),
					LogLevel.dbg
				)
			);
		}
	}

	void renderResult(TDataNode content, HTTPContext context)
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


	private void _subscribeRoutingEvents()
	{
		_rootRouter.onPostPoll ~= (HTTPContext context, bool isMatched) {
			if( isMatched )
			{	context._setuser( _accessController.authenticate(context) );
			} 
		};

		_pageRouter.onError.join( (Exception ex, HTTPContext context)
		{
			auto messages = makeErrorMsg(ex);
			loger.error(messages.details);
			renderResult(TDataNode(messages.userError), context);
			context.response.headers[`status-code`] = `500`;
			context.response.headers[`reason-phrase`] = `Internal Server Error`;
			return true;
		});
	}

	private void _initTemplateCache()
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

	// Метод перенаправляющий логи шаблонизатора в файл
	private void _ivyLogerMethod(LogInfo logInfo)
	{
		import std.datetime;
		import std.conv: text;
		LogEvent wtLogEvent;
		final switch(logInfo.type) {
			case LogInfoType.info: wtLogEvent.type = LogEventType.dbg; break;
			case LogInfoType.warn: wtLogEvent.type = LogEventType.warn; break;
			case LogInfoType.error: wtLogEvent.type = LogEventType.error; break;
			case LogInfoType.internalError: wtLogEvent.type = LogEventType.crit; break;
		}

		if( logInfo.type == LogInfoType.error || logInfo.type == LogInfoType.internalError ) {
			wtLogEvent.text = `Ivy error at: ` ~ logInfo.processedFile ~ `:` ~ logInfo.processedLine.text ~ "\n";
		}
		wtLogEvent.text ~= logInfo.msg;
		wtLogEvent.prettyFuncName = logInfo.sourceFuncName;
		wtLogEvent.file = logInfo.sourceFileName;
		wtLogEvent.line = logInfo.sourceLine;
		wtLogEvent.timestamp = std.datetime.Clock.currTime();

		_ivyLoger.writeEvent(wtLogEvent);
	}

	IAccessController accessController() @property {
		assert( _accessController, `Main service access controller is not initialized!` );
		return _accessController;
	}
}