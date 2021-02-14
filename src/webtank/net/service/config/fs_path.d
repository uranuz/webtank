module webtank.net.service.config.fs_path;

import std.json: JSONValue;

string[string] getServiceFileSystemPaths(JSONValue jsonCurrService)
{
	import webtank.net.service.config.path: resolveConfigPaths;

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