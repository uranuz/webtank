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
	if( jsonPaths.type == JSON_TYPE.OBJECT )
	if( auto rootPathPtr = rootPathName in jsonPaths )
	{
		assert( [JSON_TYPE.STRING, JSON_TYPE.NULL].canFind(rootPathPtr.type),
			`Config path "` ~ rootPathName  ~ `" value must be string or null!!!`
		);

		if( rootPathPtr.type == JSON_TYPE.STRING )
		{
			static if( shouldExpandTilde )
				rootPath = rootPathPtr.str.expandTilde();
			else
				rootPath = rootPathPtr.str;
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

	if( jsonPaths.type == JSON_TYPE.OBJECT )
	foreach( string pathName, jsonPath; jsonPaths )
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
	import std.array: replace;

	string[string] result;

	assert(
		[JSON_TYPE.OBJECT, JSON_TYPE.NULL].canFind(jsonDatabases.type),
		`Config section databases JSON value must be an object or null!!!`
	);

	if( jsonDatabases.type == JSON_TYPE.OBJECT )
	foreach( string dbCaption, jsonDb; jsonDatabases )
	{
		string connStr;
		static immutable stringOnlyParams = [
			"dbname", "host", "user", "password"
		];

		foreach( string param, ref JSONValue jValue; jsonDb )
		{
			string value;
			if( stringOnlyParams.canFind(param) )
			{
				if( jValue.type == JSON_TYPE.STRING ) {
					value = jValue.str;
				} else {
					throw new Exception(`Expected string as value of database param: ` ~ param ~ ` for DB with id: ` ~ dbCaption);
				}
			}

			if( param == "port" )
			{
				switch(jValue.type)
				{
					case JSON_TYPE.STRING: value = jValue.str; break;
					case JSON_TYPE.UINTEGER: value = jValue.uinteger.to!string; break;
					case JSON_TYPE.INTEGER: value = jValue.integer.to!string; break;
					default:
						throw new Exception(`Unexpected type of value for param: ` ~ param ~ ` for DB with id: ` ~ dbCaption);
				}
			}

			if( value.length )
			{
				if( connStr.length )
					connStr ~= ` `;
				connStr ~= param ~ "='" ~ value.replace(`'`, `\'`) ~ "'";
			}
		}
		result[dbCaption] = strip(connStr);
	}

	return result;
}

import std.typecons: Tuple;
alias RoutingConfigEntry = Tuple!(
	string, "pageURI", // Адрес расположения страницы, который обрабатывается сервисом отображения
	string, "apiURI", // Адрес для получения данных страницы в виде JSON
	string, "HTTPMethod", // Ограничение на HTTP-метод. Например, можно ограничить запросы на запись методом POST для защиты от случайных GET-запросов
	string, "ivyModule", // Имя модуля на языке Ivy для отображения результатов
	string, "ivyMethod", // Имя метода для вызова, который находится на верхнем уровне внутри модуля ivyModule
	string, "ivyModuleError", // То же что и ivyModule, но для обработки ошибок. Если не задан, то используется ivyModule
	string, "ivyMethodError", // Как и ivyMethod, но для обработки ошибок. Если не задано, то используется имя ivyMethod
	string[], "ivyParams" // Список полей web-формы, которые разрешено напрямую передавать в параметры ivyMethod (в виде строки)
);

RoutingConfigEntry[] resolvePageRoutingConfig(JSONValue pageRouting)
{
	import std.exception: enforce;
	import std.algorithm: canFind;
	import std.traits: isDynamicArray;
	import std.range: ElementType;
	RoutingConfigEntry[] entries;
	if( pageRouting.type != JSON_TYPE.ARRAY ) {
		return entries;
	}
	foreach( JSONValue jEntry; pageRouting.array )
	{
		enforce(jEntry.type == JSON_TYPE.OBJECT, `Expected JSON object as page routing entry`);
		RoutingConfigEntry entry;

		foreach( field; RoutingConfigEntry.fieldNames )
		{
			alias FieldType = typeof(__traits(getMember, entry, field));
			if( auto fieldValPtr = field in jEntry ) {
				static if( is( FieldType == string ) )
				{
					enforce(
						[JSON_TYPE.STRING, JSON_TYPE.NULL].canFind(fieldValPtr.type),
						`Expected string or null for field "` ~ field ~ `" in routing config entry`);
					if( fieldValPtr.type == JSON_TYPE.STRING ) {
						__traits(getMember, entry, field) = fieldValPtr.str;
					}
					// If null then just do nothing
				}
				else static if( isDynamicArray!FieldType && is( ElementType!FieldType == string ) )
				{
					enforce(
						[JSON_TYPE.ARRAY, JSON_TYPE.NULL].canFind(fieldValPtr.type),
						`Expected string array or null for field "` ~ field ~ `" in routing config entry`);
					if( fieldValPtr.type == JSON_TYPE.ARRAY )
					{
						foreach( val; fieldValPtr.array )
						{
							enforce(val.type == JSON_TYPE.STRING, `Expected string as item of field "` ~ field ~ `"`);
							__traits(getMember, entry, field) ~= val.str;
						}
					}
					// If null then just do nothing
				}
				else
					static assert(false, `Unhandled type of RoutingConfigEntry field`);
			}
		}
		entries ~= entry;
	}
	return entries;
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
		"siteJSON_RPC": "jsonrpc/",
		"siteWebFormAPI": "api/"
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

RoutingConfigEntry[] getPageRoutingConfig(JSONValue jsonCurrService)
{
	JSONValue pageRouting;
	if( "pageRouting" in jsonCurrService ) {
		pageRouting = jsonCurrService["pageRouting"];
	}
	return resolvePageRoutingConfig(pageRouting);
}


mixin template ServiceConfigImpl()
{
protected:
	JSONValue _jsonConfig;
	string[string] _fileSystemPaths;
	string[string] _virtualPaths;
	string[string] _dbConnStrings;
	RoutingConfigEntry[] _pageRouting;

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
		_pageRouting = getPageRoutingConfig(service);
	}

	override string endpoint(string serviceName, string endpointName)
	{
		import std.json: JSON_TYPE, JSONValue;
		JSONValue service = _jsonConfig.getServiceConfig(serviceName);
		if( `endpoints` !in service )
			return null;
		JSONValue endpoints = service[`endpoints`];
		if( endpoints.type != JSON_TYPE.OBJECT )
			return null;
		if( auto endpoint = endpointName in endpoints )
			return endpoint.type == JSON_TYPE.STRING? endpoint.str: null;
		return null;
	}
}