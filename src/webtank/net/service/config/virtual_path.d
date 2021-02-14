module webtank.net.service.config.virtual_path;

import std.json: JSONValue;

string[string] getServiceVirtualPaths(JSONValue jsonCurrService)
{
	import webtank.net.service.config.path: resolveConfigPaths;
	
	JSONValue jsonVirtualPaths;
	if( "virtualPaths" in jsonCurrService) {
		jsonVirtualPaths = jsonCurrService["virtualPaths"];
	}

	// Захардкодим адреса сайта, используемые по-умолчанию
	string[string] defaultVirtualPaths = [
		"siteRoot": "/",
		"sitePublic": "pub/",
		"siteDynamic": "dyn/",
		"siteJSON_RPC": "jsonrpc/",
		"siteWebFormAPI": "api/"
	];

	return resolveConfigPaths!(false)(jsonVirtualPaths, defaultVirtualPaths, "siteRoot");
}