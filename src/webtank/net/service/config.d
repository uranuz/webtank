module webtank.net.service.config;

import std.json, std.file, std.path;

import webtank.net.utils: buildNormalPath;

/++
$(LOCALE_EN_US
	Function resolves paths that are set by $(D_PARAM jsonPaths). All paths could be realtive
	to root path, which is path with name $(D_PARAM rootPathName). Root path can't be
	relative but can be empty or not exist inside $(D_PARAM jsonPaths). In that case it
	will be replaced by defaultPaths[rootPathName]
	Params:
		jsonPaths = JSONValue that must be object, representing list of paths
			using format "pathName" : "path"
		defaultPaths = Set of path that are used when some of path needed
			by application are not present in config or empty
		rootPathName = Path name considered as name for root path.
			Root path is used for resolving relative path in config
			or inside $(D_PARAM defaultPaths) array
)
$(LOCALE_RU_RU
	Функция выполняет разрешение путей в конфигурации
	Params:
	jsonPaths = JSONValue значения типа JSON_TYPE.OBJECT, представляющие список путей
	в формате "названиеПути" : "путь"
	defaultPaths = Набор путей по умолчанию на случай, если какие-то из требуемых
		путей окажутся не задаными
	rootPathName = Название для пути, рассматриваемого как корневой путь
)
+/
string[string] resolveConfigPaths(bool shouldExpandTilde = false)(
	JSONValue jsonPaths,
	string[string] defaultPaths,
	string rootPathName = "rootPath"
) {
	import std.algorithm: canFind;
	assert( rootPathName.length > 0, "Root path name must not be empty" );
	string[string] result;

	assert(
		[JSON_TYPE.OBJECT, JSON_TYPE.NULL].canFind(jsonPaths.type),
		`Config paths JSON value must be an object or null!!!`
	);

	string rootPath;
	if( jsonPaths.type == JSON_TYPE.OBJECT && rootPathName in jsonPaths )
	{
		assert( jsonPaths[rootPathName].type == JSON_TYPE.STRING ||
			jsonPaths[rootPathName].type == JSON_TYPE.NULL,
			`Config path "` ~ rootPathName  ~ `" value must be string or null!!!`
		);

		if( jsonPaths[rootPathName].type == JSON_TYPE.STRING )
		{
			static if( shouldExpandTilde )
				rootPath = jsonPaths[rootPathName].str.expandTilde();
			else
				rootPath = jsonPaths[rootPathName].str;
		}

	}

	if( !rootPath )
	{
		static if( shouldExpandTilde )
			rootPath = defaultPaths.get(rootPathName, null).expandTilde();
		else
			rootPath = defaultPaths.get(rootPathName, null);
	}

	assert( rootPath.length > 0 && isAbsolute(rootPath), `Config path "` ~ rootPathName  ~ `" value must be absolute!!!` );

	if( jsonPaths.type == JSON_TYPE.OBJECT ) foreach( string pathName, jsonPath; jsonPaths )
	{
		if( pathName == rootPathName )
			continue; //Ignore root path here

		//Extracting only non-empty strings
		if( jsonPath.type == JSON_TYPE.STRING && jsonPath.str.length > 0 )
		{
			static if( shouldExpandTilde )
				result[pathName] = buildNormalPath( rootPath, jsonPath.str.expandTilde() );
			else
				result[pathName] = buildNormalPath( rootPath, jsonPath.str );
		}
	}

	foreach( string pathName, path; defaultPaths )
	{
		if( pathName == rootPathName )
			continue; //Ignore root path here

		if( pathName !in result )
		{
			static if( shouldExpandTilde )
				result[pathName] = buildNormalPath( rootPath, defaultPaths[pathName].expandTilde() );
			else
				result[pathName] = buildNormalPath( rootPath, defaultPaths[pathName] );
		}
	}

	result[rootPathName] = rootPath;

	return result;
}

string[string] resolveConfigDatabases(JSONValue jsonDatabases)
{
	import std.conv, std.string;
	import std.algorithm: canFind;

	string[string] result;

	assert(
		[JSON_TYPE.OBJECT, JSON_TYPE.NULL].canFind(jsonDatabases.type),
		`Config section databases JSON value must be an object or null!!!`
	);

	if( jsonDatabases.type == JSON_TYPE.OBJECT ) foreach( string dbCaption, jsonDb; jsonDatabases )
	{
		string connStr = "";
		bool isHostFound = false;

		if( "dbname" in jsonDb )
		{
			if( jsonDb["dbname"].type == JSON_TYPE.STRING ) {
				connStr ~= "dbname=" ~ jsonDb["dbname"].str ~ " ";
			}
		}

		if( "host" in jsonDb )
		{
			if( jsonDb["host"].type == JSON_TYPE.STRING )
			{
				isHostFound = true;
				connStr ~= "host=" ~ jsonDb["host"].str ~ " ";
			}
		}

		if( "port" in jsonDb )
		{
			if( jsonDb["host"].type == JSON_TYPE.UINTEGER )
			{
				if( !isHostFound )
					connStr ~= "host=127.0.0.1";

				connStr ~= ":" ~ jsonDb["host"].uinteger.to!string ~ " ";
			}
		}

		if( "username" in jsonDb )
		{
			if( jsonDb["username"].type == JSON_TYPE.STRING ) {
				connStr ~= "user=" ~ jsonDb["username"].str ~ " ";
			}
		}

		if( "password" in jsonDb )
		{
			if( jsonDb["password"].type == JSON_TYPE.STRING ) {
				connStr ~= "password=" ~ jsonDb["password"].str ~ " ";
			}
		}

		result[dbCaption] = strip(connStr);
	}

	return result;
}

JSONValue getServiceConfig(JSONValue jsonConfig, string serviceName)
{
	assert( jsonConfig.type == JSON_TYPE.OBJECT, `Config root JSON value must be object!!!` );

	assert( "services" in jsonConfig, `Config must contain "services" object!!!` );
	JSONValue jsonServices = jsonConfig["services"];
	assert( jsonServices.type == JSON_TYPE.OBJECT, `Config services JSON value must be object!!!` );

	assert( serviceName in jsonServices, `Config section "services" must contain "` ~ serviceName ~ `" object!!!` );
	JSONValue jsonCurrService = jsonServices[serviceName];
	assert( jsonCurrService.type == JSON_TYPE.OBJECT, `Config section "services.` ~ serviceName ~ `" must be object!!!` );

	return jsonCurrService;
}

static immutable defaultServicesConfigFile = `services_config.json`;

JSONValue readServiceConfigFile(string serviceName, string fileName = defaultServicesConfigFile)
{
	import std.file: read, exists;
	assert(exists(fileName), `Services configuration file "` ~ fileName ~ `" doesn't exist!`);

	JSONValue fullJSONConfig = parseJSON(cast(string) read(fileName));
	return fullJSONConfig.getServiceConfig(serviceName);
}

string[string] getServiceFileSystemPaths(JSONValue jsonCurrService)
{
	import std.algorithm: canFind;
	JSONValue jsonFSPaths;
	if( "fileSystemPaths" in jsonCurrService ) {
		jsonFSPaths = jsonCurrService["fileSystemPaths"];
	}

	//Захардкодим пути в файловой ситеме, используемые по-умолчанию
	string[string] defaultFileSystemPaths = [
		"siteRoot": "~/sites/site_root/",

		"sitePublic": "pub/",
		"siteIvyTemplates": "res/templates/",

		"siteLogs": "logs/",
		"siteErrorLogFile": "logs/error.log",
		"siteEventLogFile": "logs/event.log",
		"siteDatabaseLogFile": "logs/database.log"
	];

	return resolveConfigPaths!(true)(jsonFSPaths, defaultFileSystemPaths, "siteRoot");
}

string[string] getServiceVirtualPaths(JSONValue jsonCurrService)
{
	JSONValue jsonVirtualPaths;
	if( "virtualPaths" in jsonCurrService) {
		jsonVirtualPaths = jsonCurrService["virtualPaths"];
	}

	//Захардкодим адреса сайта, используемые по-умолчанию
	string[string] defaultVirtualPaths = [
		"siteRoot": "/",
		"sitePublic": "pub/",
		"siteDynamic": "dyn/",
		"siteJSON_RPC": "jsonrpc/"
	];

	return resolveConfigPaths!(false)(jsonVirtualPaths, defaultVirtualPaths, "siteRoot");
}

string[string] getServiceDatabases(JSONValue jsonCurrService)
{
	//Вытаскиваем информацию об используемых базах данных
	JSONValue jsonDatabases;
	if( "databases" in jsonCurrService ) {
		jsonDatabases = jsonCurrService["databases"];
	}

	return resolveConfigDatabases(jsonDatabases);
}


mixin template ServiceConfigImpl()
{
protected:
	JSONValue _jsonConfig;
	string[string] _fileSystemPaths;
	string[string] _virtualPaths;
	string[string] _dbConnStrings;

public:
	override string[string] virtualPaths() @property {
		return _virtualPaths;
	}

	override string[string] fileSystemPaths() @property {
		return _fileSystemPaths;
	}

	override string[string] dbConnStrings() @property {
		return _dbConnStrings;
	}

	void readConfig()
	{
		import std.file: read, exists;
		import std.json: parseJSON;
		assert(
			exists(defaultServicesConfigFile),
			`Services configuration file "` ~ defaultServicesConfigFile ~ `" doesn't exist!`
		);

		_jsonConfig = parseJSON(cast(string) read(defaultServicesConfigFile));

		JSONValue service = _jsonConfig.getServiceConfig(_serviceName);
		_fileSystemPaths = getServiceFileSystemPaths(service);
		_virtualPaths = getServiceVirtualPaths(service);
		_dbConnStrings = getServiceDatabases(service);
	}

	override string getEndpointAddress(string serviceName, string endpointName)
	{
		import std.json: JSON_TYPE, JSONValue;
		JSONValue service = _jsonConfig.getServiceConfig(serviceName);
		if( `endpoints` !in service )
			return null;
		JSONValue endpoints = service[`endpoints`];
		if( endpoints.type != JSON_TYPE.OBJECT )
			return null;
		if( endpointName !in endpoints )
			return null;
		JSONValue endpoint = service[`endpoints`];
		return (endpoint.type == JSON_TYPE.STRING? endpoint.str: null);
	}
}