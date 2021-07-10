module webtank.ivy.engine;

import ivy.engine: IvyEngine;

class WebtankIvyEngine: IvyEngine
{
	import webtank.common.log.writer.iface: LogWriter;
	import webtank.ivy.service.log_writer: IvyLogWriter;

private:
	IvyLogWriter _loger;

public:
	this(string[] importPaths, LogWriter webtankLog = null)
	{
		import ivy.engine.config: IvyEngineConfig;
		import webtank.ivy.directive.standard_factory: webtankDirFactory;
		
		import std.exception: enforce;
		enforce(importPaths.length > 0, "Import paths for templates are required");

		IvyEngineConfig config;
		config.importPaths = importPaths;
		config.fileExtension = ".ivy";

		if( webtankLog !is null )
			_loger = new IvyLogWriter(webtankLog);

		if( _loger !is null )
		{
			// Направляем логирование шаблонизатора в файл
			config.parserLoger = &this._loger.writeEvent;
			config.compilerLoger = &this._loger.writeEvent;
			config.interpreterLoger = &this._loger.writeEvent;
		}

		config.directiveFactory = webtankDirFactory;

		debug config.clearCache = true;

		super(config);
	}
}