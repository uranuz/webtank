module webtank.net.service.config.path;

import std.json: JSONValue, JSONType;

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
	import webtank.net.utils: buildNormalPath;
	import std.path: expandTilde, isAbsolute;

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