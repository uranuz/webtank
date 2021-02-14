module webtank.ivy.service.view.webpack_manifest;

class WebpackManifest
{
protected:
	string[] _webpackLibs;
	size_t[string] _webpackModules;

public:
	this(string fsPublic) {
		reload(fsPublic);
	}

	/// Вычитываем манифесты для JS-точек входа
	final void reload(string fsPublic)
	{
		import std.algorithm: countUntil, startsWith;
		import std.file: dirEntries, SpanMode, isFile, exists, read;
		import std.json: parseJSON, JSONValue, JSONType;
		import std.range: dropExactly, dropBackExactly;
		import std.path: buildNormalizedPath;
		import std.exception: enforce;

		_webpackLibs.length = 0;
		_webpackModules.clear();

		string manifestsFolder = fsPublic ~ `manifest/`;
		string manifestFileSuffix = `.manifest.json`;

		foreach( string manifestFileName; dirEntries(manifestsFolder, `*` ~ manifestFileSuffix, SpanMode.breadth) )
		{
			if( !isFile(manifestFileName) || !exists(manifestFileName) )
				continue;
			JSONValue jManifest = parseJSON(cast(string) read(manifestFileName));
			enforce(jManifest.type == JSONType.object, `Webpack DllPlugin library manifest expected to be JSON-object: ` ~ manifestFileName);

			auto jLibraryPtr = `name` in jManifest;
			auto jContentPtr = `content` in jManifest;
			enforce(
				jLibraryPtr && jLibraryPtr.type == JSONType.string,
				`Expected name of library in Webpack DllPlugin manifest: ` ~ manifestFileName);
			enforce(
				jContentPtr && jContentPtr.type == JSONType.object,
				`Expected content of library in Webpack DllPlugin manifest: ` ~ manifestFileName);

			string relLibFileName = manifestFileName
				.dropExactly(manifestsFolder.length)
				.dropBackExactly(manifestFileSuffix.length);
			string absLibFileName = buildNormalizedPath(fsPublic, relLibFileName ~ ".js");
			enforce(exists(absLibFileName), `Library file name should exist: ` ~ absLibFileName);
			enforce(isFile(absLibFileName), `Library is not a file: ` ~ absLibFileName);

			ptrdiff_t libIndex = _webpackLibs.countUntil(relLibFileName);
			if( libIndex < 0 )
			{
				libIndex = _webpackLibs.length;
				_webpackLibs ~= relLibFileName;
			}
			foreach( string moduleName, val; jContentPtr.object ) {
				_webpackModules[moduleName] = libIndex;
			}
		}
	}

	string getLibPath(string moduleName)
	{
		import std.exception: enforce;

		if( moduleName.length == 0 ) {
			return null;
		}
		moduleName = `./` ~ moduleName ~ `.js`;
		auto libIndexPtr = moduleName in _webpackModules;
		enforce(libIndexPtr !is null, `Unable to find webpack JS-library for module: ` ~ moduleName);
		size_t libIndex = *libIndexPtr;
		enforce(libIndex < _webpackLibs.length, `Unable to find webpack JS-library with index. Possibly bug in code`);
		return _webpackLibs[libIndex];
	}

}