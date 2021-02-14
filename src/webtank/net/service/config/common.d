module webtank.net.service.config.common;

import std.json: JSONValue, JSONType, parseJSON;

static immutable defaultServicesConfigFile = `services_config.json`;

JSONValue readServicesConfigFile(string fileName = defaultServicesConfigFile)
{
	import std.file: read, exists;
	import std.exception: enforce;

	enforce(exists(fileName), `Services configuration file "` ~ fileName ~ `" doesn't exist!`);
	return parseJSON(cast(string) read(fileName));
}

JSONValue readServiceConfigFile(string serviceName, string fileName = defaultServicesConfigFile) {
	return readServicesConfigFile(fileName).getServiceConfig(serviceName);
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
