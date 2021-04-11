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
		import ivy.engine_config: IvyConfig;
		import webtank.ivy.directive.standard_factory: webtankDirFactory;
		
		import std.exception: enforce;
		enforce(importPaths.length > 0, "Import paths for templates are required");

		IvyConfig ivyConfig;
		ivyConfig.importPaths = importPaths;
		ivyConfig.fileExtension = ".ivy";

		if( webtankLog !is null )
			_loger = new IvyLogWriter(webtankLog);

		if( _loger !is null )
		{
			// Направляем логирование шаблонизатора в файл
			ivyConfig.parserLoger = &this._loger.writeEvent;
			ivyConfig.compilerLoger = &this._loger.writeEvent;
			ivyConfig.interpreterLoger = &this._loger.writeEvent;
		}

		ivyConfig.directiveFactory = webtankDirFactory;

		debug ivyConfig.clearCache = true;

		super(ivyConfig);
	}
}