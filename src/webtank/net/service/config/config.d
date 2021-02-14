module webtank.net.service.config.config;

import webtank.net.service.config.iface: IServiceConfig;

class ServiceConfig: IServiceConfig
{
	import webtank.net.service.config.common: readServicesConfigFile, getServiceConfig;
	import webtank.net.service.config.fs_path: getServiceFileSystemPaths;
	import webtank.net.service.config.database: getServiceDatabases;
	import webtank.net.service.config.page_routing: getPageRoutesConfig, RoutingConfigEntry;
	import webtank.net.service.config.endpoint: getServicesEndpoints;
	import webtank.net.service.config.virtual_path: getServiceVirtualPaths;

	import webtank.net.service.config.service_role: getServiceRoles;

	import std.json: JSONValue;

protected:
	string _serviceName;

	JSONValue _allConfig;

	JSONValue _serviceConfig;

	// Внешний сервис может испольнять какую-то *роль* по отношению к текущему:
	// Например, может быть сервисы истории, либо сервисы аутентификации, либо осн. бакэнд (для сервиса представления).
	// Соответственно, хочется, чтобы в эндпоинте при обращению к этому сервису можно было указать его *роль*,
	// а не указывать конкретное имя сервиса. Например, один и тот же сервис может *играть несколько ролей*,
	// а может быть так, что эти роли разнесены по нескольким разным сервисам.
	// В этом словаре храним соответствие имени роли реальному названию сервиса (берется из конфига).
	string[string] _serviceRoles;

	string[string][string] _endpoints;

	string[string] _virtualPaths;

	string[string] _fileSystemPaths;
	string[string] _dbConnStrings;
	RoutingConfigEntry[] _pageRouting;

public:
	this(string serviceName)
	{
		import std.exception: enforce;
		import std.range: empty;

		enforce(!serviceName.empty, "Service name is required");
		_serviceName = serviceName;
		readConfig();
	}

	void readConfig()
	{
		_allConfig = readServicesConfigFile();

		_serviceConfig = _allConfig.getServiceConfig(_serviceName);

		_fileSystemPaths = getServiceFileSystemPaths(_serviceConfig);
		_dbConnStrings = getServiceDatabases(_serviceConfig);
		_pageRouting = getPageRoutesConfig(_serviceConfig);

		_endpoints = getServicesEndpoints(_allConfig);
		_virtualPaths = getServiceVirtualPaths(_serviceConfig);

		/*
		debug {
			import std.stdio;
			writeln("ENDPOINTS: ", _endpoints);
			writeln("VPATHS: ", _virtualPaths);
		}
		*/

		// Get service role aliases
		_serviceRoles = getServiceRoles(_serviceConfig);
	}

	override string serviceName() @property {
		return _serviceName;
	}

	override string[string][string] endpoints() @property {
		return _endpoints;
	}

	override string[string] virtualPaths() @property {
		return _virtualPaths;
	}

	override string[string] fileSystemPaths() @property {
		return _fileSystemPaths;
	}

	override string[string] dbConnStrings() @property {
		return _dbConnStrings;
	}

	override RoutingConfigEntry[] pageRouting() @property {
		return _pageRouting;
	}

	override string[string] serviceRoles() @property {
		return _serviceRoles;
	}

	override JSONValue rawConfig() @property {
		return _serviceConfig;
	}

	override string endpoint(string targetService, string endpoint)
	{
		if( auto realNamePtr = targetService in _serviceRoles ) {
			// Происходит доступ по роли сервиса
			return _getServiceEndpoint(*realNamePtr, endpoint);
		}
		// Происходит доступ по реальному имени сервиса
		return _getServiceEndpoint(targetService, endpoint);
	}

	string _getServiceEndpoint(string targetService, string endpoint)
	{
		import std.exception: enforce;

		endpoint = endpoint.length > 0? endpoint: "default";

		auto serviceEndpointsPtr = targetService in _endpoints; 
		enforce(serviceEndpointsPtr, "No service with name \"" ~ targetService ~ "\" in config");
		auto uriPtr = endpoint in (*serviceEndpointsPtr);
		enforce(uriPtr, "No endpoint \"" ~ endpoint ~ "\" for service \"" ~ targetService ~ "\"");
		return *uriPtr;
	}
}