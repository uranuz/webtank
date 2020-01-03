module webtank.net.service.config;

import std.json, std.file, std.path;

import webtank.net.utils: buildNormalPath;

/++
$(LANG_EN
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
$(LANG_RU
	Функция выполняет разрешение путей в конфигурации
	Params:
	jsonPaths = JSONValue значения типа JSONType.object, представляющие список путей
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
	import std.exception: enforce;
	enforce(rootPathName.length > 0, "Root path name must not be empty");
	string[string] result;

	enforce(
		[JSONType.object, JSONType.null_].canFind(jsonPaths.type),
		`Config paths JSON value must be an object or null!!!`);

	string rootPath;
	if( jsonPaths.type == JSONType.object )
	if( auto rootPathPtr = rootPathName in jsonPaths )
	{
		enforce(
			[JSONType.string, JSONType.null_].canFind(rootPathPtr.type),
			`Config path "` ~ rootPathName  ~ `" value must be string or null!!!`);

		if( rootPathPtr.type == JSONType.string ) {
			rootPath = rootPathPtr.str;
		}

	}

	if( !rootPath ) {
		rootPath = defaultPaths.get(rootPathName, null);
	}

	static if( shouldExpandTilde ) {
		rootPath = rootPath.expandTilde();
	}

	enforce(
		rootPath.length > 0 && isAbsolute(rootPath),
		`Config path "` ~ rootPathName  ~ `" value must be absolute!!!`);

	if( jsonPaths.type == JSONType.object )
	foreach( string pathName, jsonPath; jsonPaths )
	{
		if( pathName == rootPathName )
			continue; //Ignore root path here

		//Extracting only non-empty strings
		if( jsonPath.type == JSONType.string && jsonPath.str.length > 0 )
		{
			string strPath = jsonPath.str;
			static if( shouldExpandTilde ) {
				strPath = strPath.expandTilde();
			}

			result[pathName] = buildNormalPath(rootPath, strPath);
		}
	}

	foreach( string pathName, path; defaultPaths )
	{
		if( pathName == rootPathName )
			continue; //Ignore root path here

		if( pathName !in result )
		{
			string strPath = defaultPaths[pathName];
			static if( shouldExpandTilde ) {
				strPath = strPath.expandTilde();
			}
			result[pathName] = buildNormalPath(rootPath, strPath);
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
	import std.exception: enforce;

	string[string] result;

	enforce(
		[JSONType.object, JSONType.null_].canFind(jsonDatabases.type),
		`Config section databases JSON value must be an object or null!!!`);

	if( jsonDatabases.type == JSONType.object )
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
				if( jValue.type == JSONType.string ) {
					value = jValue.str;
				} else {
					throw new Exception(`Expected string as value of database param: ` ~ param ~ ` for DB with id: ` ~ dbCaption);
				}
			}

			if( param == "port" )
			{
				switch(jValue.type)
				{
					case JSONType.string: value = jValue.str; break;
					case JSONType.uinteger: value = jValue.uinteger.to!string; break;
					case JSONType.integer: value = jValue.integer.to!string; break;
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
	string, "service", // Имя сервиса для определения адреса для отправки запроса, если указан относительный requestURI
	string, "endpoint", // Имя точки доступа для определения адреса для отправки запроса, если указан относительный requestURI
	string, "requestURI", // Адрес для получения данных страницы в виде JSON
	string, "HTTPMethod", // Ограничение на HTTP-метод. Например, можно ограничить запросы на запись методом POST для защиты от случайных GET-запросов
	string, "ivyModule", // Имя модуля на языке Ivy для отображения результатов
	string, "ivyMethod", // Имя метода для вызова, который находится на верхнем уровне внутри модуля ivyModule
	string, "ivyModuleError", // То же что и ivyModule, но для обработки ошибок. Если не задан, то используется ivyModule
	string, "ivyMethodError" // Как и ivyMethod, но для обработки ошибок. Если не задано, то используется имя ivyMethod
);

RoutingConfigEntry[] resolvePageRoutingConfig(JSONValue pageRouting)
{
	import std.exception: enforce;
	import std.algorithm: canFind;
	import std.traits: isDynamicArray;
	import std.range: ElementType;
	RoutingConfigEntry[] entries;
	if( pageRouting.type != JSONType.array ) {
		return entries;
	}
	foreach( JSONValue jEntry; pageRouting.array )
	{
		enforce(jEntry.type == JSONType.object, `Expected JSON object as page routing entry`);
		RoutingConfigEntry entry;

		foreach( field; RoutingConfigEntry.fieldNames )
		{
			alias FieldType = typeof(__traits(getMember, entry, field));
			if( auto fieldValPtr = field in jEntry ) {
				static if( is( FieldType == string ) )
				{
					enforce(
						[JSONType.string, JSONType.null_].canFind(fieldValPtr.type),
						`Expected string or null for field "` ~ field ~ `" in routing config entry`);
					if( fieldValPtr.type == JSONType.string ) {
						__traits(getMember, entry, field) = fieldValPtr.str;
					}
					// If null then just do nothing
				}
				else static if( isDynamicArray!FieldType && is( ElementType!FieldType == string ) )
				{
					enforce(
						[JSONType.array, JSONType.null_].canFind(fieldValPtr.type),
						`Expected string array or null for field "` ~ field ~ `" in routing config entry`);
					if( fieldValPtr.type == JSONType.array )
					{
						foreach( val; fieldValPtr.array )
						{
							enforce(val.type == JSONType.string, `Expected string as item of field "` ~ field ~ `"`);
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

JSONValue getServicesConfig(JSONValue jsonConfig)
{
	import std.exception: enforce;
	enforce( jsonConfig.type == JSONType.object, `Config root JSON value must be object!!!` );

	enforce( "services" in jsonConfig, `Config must contain "services" object!!!` );
	JSONValue jsonServices = jsonConfig["services"];
	enforce( jsonServices.type == JSONType.object, `Config services JSON value must be object!!!` );
	return jsonServices;
}

JSONValue getServiceConfig(JSONValue jsonConfig, string serviceName)
{
	import std.exception: enforce;
	JSONValue jsonServices = getServicesConfig(jsonConfig);

	enforce( serviceName in jsonServices, `Config section "services" must contain "` ~ serviceName ~ `" object!!!` );
	JSONValue jsonCurrService = jsonServices[serviceName];
	enforce( jsonCurrService.type == JSONType.object, `Config section "services.` ~ serviceName ~ `" must be object!!!` );

	return jsonCurrService;
}

static immutable defaultServicesConfigFile = `services_config.json`;

JSONValue readServiceConfigFile(string serviceName, string fileName = defaultServicesConfigFile)
{
	import std.file: read, exists;
	import std.exception: enforce;
	enforce(exists(fileName), `Services configuration file "` ~ fileName ~ `" doesn't exist!`);

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

string[string] getServiceDeps(JSONValue jsonCurrService)
{
	import std.exception: enforce;
	auto serviceDepsPtr = "serviceDeps" in jsonCurrService;
	string[string] res;
	if( serviceDepsPtr is null ) {
		return res;
	}
	foreach( string serviceRole, JSONValue jServiceName; serviceDepsPtr.object )
	{
		enforce(jServiceName.type == JSONType.string, "Expected string as service name in serviceDeps");
		res[serviceRole] = jServiceName.str;
	}
	return res;
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
	import webtank.net.service.config:
		defaultServicesConfigFile,
		getServiceConfig,
		getServiceFileSystemPaths,
		getServiceDatabases,
		getPageRoutingConfig,
		getServicesConfig,
		getServiceVirtualPaths,
		getServiceDeps;
protected:
	JSONValue _allConfig;

	JSONValue _serviceConfig;

	string[string][string] _endpoints;

	// Внешний сервис может испольнять какую-то *роль* по отношению к текущему:
	// Например, может быть сервисы истории, либо сервисы аутентификации, либо осн. бакэнд (для сервиса представления).
	// Соответственно, хочется, чтобы в эндпоинте при обращению к этому сервису можно было указать его *роль*,
	// а не указывать конкретное имя сервиса. Например, один и тот же сервис может *играть несколько ролей*,
	// а может быть так, что эти роли разнесены по нескольким разным сервисам.
	// В этом словаре храним соответствие имени роли реальному названию сервиса (берется из конфига).
	string[string] _serviceDeps;

	string[string] _fileSystemPaths;
	string[string] _dbConnStrings;
	RoutingConfigEntry[] _pageRouting;

public:
	override string[string] virtualPaths() @property {
		return _endpoints.get(_serviceName, null);
	}

	override string[string] fileSystemPaths() @property {
		return _fileSystemPaths;
	}

	override string[string] dbConnStrings() @property {
		return _dbConnStrings;
	}

	override string[string] serviceDeps() @property {
		return _serviceDeps;
	}

	override JSONValue rawConfig() @property {
		return _serviceConfig;
	}

	void readConfig()
	{
		import std.file: read, exists;
		import std.json: parseJSON;
		import std.exception: enforce;
		enforce(
			exists(defaultServicesConfigFile),
			`Services configuration file "` ~ defaultServicesConfigFile ~ `" doesn't exist!`);

		_allConfig = parseJSON(cast(string) read(defaultServicesConfigFile));

		_serviceConfig = _allConfig.getServiceConfig(_serviceName);

		_fileSystemPaths = getServiceFileSystemPaths(_serviceConfig);
		_dbConnStrings = getServiceDatabases(_serviceConfig);
		_pageRouting = getPageRoutingConfig(_serviceConfig);

		// Get endpoints for all services in config
		foreach( string srvName, JSONValue service; _allConfig.getServicesConfig().object ) {
			_endpoints[srvName] = getServiceVirtualPaths(service);
		}

		// Get service role aliases
		_serviceDeps = getServiceDeps(_serviceConfig);
	}

	override string endpoint(string serviceName, string endpointName)
	{
		if( auto realNamePtr = serviceName in _serviceDeps ) {
			// Происходит доступ по роли сервиса
			return _getServiceEndpoint(*realNamePtr, endpointName);
		}
		// Происходит доступ по реальному имени сервиса
		return _getServiceEndpoint(serviceName, endpointName);
	}

	string _getServiceEndpoint(string serviceName, string endpointName)
	{
		import std.exception: enforce;
		import std.json: JSONType;
		import std.range: empty;
		import webtank.net.uri: URI;
		auto vPathsPtr = serviceName in _endpoints; 
		enforce(vPathsPtr, `No service with name "` ~ serviceName ~ `" in config`);
		string vPathName = endpointName.length > 0? endpointName: `default`;
		auto uriPtr = vPathName in (*vPathsPtr);
		enforce(uriPtr, `No vpath "` ~ vPathName ~ `" for service "` ~ serviceName ~ `"`);
		URI uri = URI(*uriPtr);

		auto serviceURIPtr = `URI` in rawConfig;
		enforce(serviceURIPtr, `No service URI in config`);
		enforce(serviceURIPtr.type == JSONType.string, `Expected string as service URI in config`);
		URI serviceURI = URI(serviceURIPtr.str);

		// Схема и хост с портом берутся из адреса сервиса, если не заданы в точке доступа
		if( uri.scheme.empty ) {
			uri.scheme = serviceURI.scheme;
		}

		if( uri.authority.empty ) {
			uri.authority = serviceURI.authority;
		}
		return uri.toRawString();
	}
}