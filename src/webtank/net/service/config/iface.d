module webtank.net.service.config.iface;

// Отвечает за получение адресов к удаленным серверам
interface IServiceConfig
{
	import std.json: JSONValue;

	import webtank.net.service.config.page_routing: RoutingConfigEntry;

	string serviceName() @property;
	string[string][string] endpoints() @property;
	string[string] virtualPaths() @property;
	string[string] fileSystemPaths() @property;
	string[string] dbConnStrings() @property;
	RoutingConfigEntry[] pageRouting() @property;
	string[string] serviceRoles() @property;
	JSONValue rawConfig() @property;
	string endpoint(string serviceName, string endpointName = null);
}
