module webtank.ui.templating;

import webtank.templating.plain_templater;

version(devel)
	private enum useTemplateCache = false;
else
	private enum useTemplateCache = true;

private __gshared PlainTemplateCache!(useTemplateCache) _templateCache;
private __gshared string _templatesDir;

shared static this()
{
	_templateCache = new PlainTemplateCache!(useTemplateCache)();
}

void setTemplatesDir(string path)
{
	_templatesDir = path;
}

PlainTemplater getPlainTemplater(string tplFileName, bool shouldInit = true)
{	
	import std.path;
	
	if( !std.path.isRooted(tplFileName) )
		tplFileName = std.path.buildNormalizedPath(_templatesDir, tplFileName);
	
	PlainTemplater tpl = _templateCache.get(tplFileName);
	
	if( shouldInit )
	{	//Задаём местоположения всяких файлов

	}
	
	return tpl;
}