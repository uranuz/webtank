module webtank.net.service.config.endpoint;

import std.json: JSONValue;

string[string][string] getServicesEndpoints(JSONValue allConfig)
{
	import webtank.net.service.config.virtual_path: getServiceVirtualPaths;
	import webtank.net.service.config.common: getServicesConfig;

	import std.exception: enforce;
	import std.json: JSONType;
	import std.range: empty;
	import webtank.net.uri: URI;

	string[string][string] res;

	foreach( string serviceName, JSONValue service; allConfig.getServicesConfig().object )
	{
		auto serviceURIPtr = "URI" in service;
		if( serviceURIPtr is null )
			continue; // Cannot resolve endpoint for service without URI
		enforce(serviceURIPtr.type == JSONType.string, "Expected string as service URI in config");
		URI serviceURI = URI(serviceURIPtr.str);

		string[string] serviceEndpoints;
		foreach( endpoint, vpath; getServiceVirtualPaths(service) )
		{
			URI uri = URI(vpath);

			// Схема и хост с портом берутся из адреса сервиса, если не заданы в точке доступа
			if( uri.scheme.empty ) {
				uri.scheme = serviceURI.scheme;
			}

			if( uri.authority.empty ) {
				uri.authority = serviceURI.authority;
			}
			serviceEndpoints[endpoint] = uri.toRawString();
		}

		res[serviceName] = serviceEndpoints;
	}

	return res;
}