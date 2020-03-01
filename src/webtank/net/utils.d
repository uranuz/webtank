 module webtank.net.utils;

import std.utf, std.conv;

///Функция "очистки" текста от HTML-тэгов
string HTMLEscapeText(string srcStr)
{	dstring result;
	auto str = toUTF32(srcStr);
	size_t i = 0;
	size_t lastBracketPos = size_t.max;
	for( ; i < str.length; i++ )
	{	if( str[i] == '<' || str[i] == '>' )
		{	result ~= str[ (lastBracketPos + 1) .. i ] ~ ( (str[i] == '<') ? "&lt;"d : "&gt;"d ) ;
			lastBracketPos = i;
		}
	}
	result ~= str[ (lastBracketPos + 1) .. $ ];
	return toUTF8(result);
}

string printHTMLAttr(V)(string attr, V value)
{	//TODO: Сделать защиту от HTML-инъекций для имени аттрибута
	string strValue = value.to!string;
	return (
		( attr.length > 0 && strValue.length > 0 )
		? ( ` ` ~ attr ~ `="` ~ HTMLEscapeValue( strValue )  ~ `"` )
		: ``
	);
}

//Функция замены определённых строк на другие строки
//srcStr - исходная строка. Mapping - карта, по которой происходит замена
//Синтаксис mapping = [ "что1": "чем1", "что2": "чем2", "что3": "чем3" ]
dstring replace(dstring src, in dstring[dstring] mapping)
{
	dstring result;
	import std.algorithm;
	auto whats = sort!("a.length > b.length")(mapping.keys.dup);
	size_t i = 0;
	size_t searchStartPos = 0;
	for( ; i < src.length; i++ )
	{	foreach( what; whats )
		{	if( ( (i + what.length) <= src.length ) && ( what.length >= 0 ) )
			{	if( src[ i .. (i + what.length) ] == what )
				{	result ~= src[ searchStartPos .. i ] ~ mapping[what] ;
					searchStartPos = i + what.length;
					i += what.length - 1;
					break;
				}
			}
		}
	}
	result ~= src[ searchStartPos .. $ ];
	return result;
}

string replace(string src, in string[string] mapping)
{	dstring[dstring] UTF32Mapping;
	foreach( key, value; mapping )
		UTF32Mapping[ toUTF32(key) ] = toUTF32(value);
	return toUTF8( replace( toUTF32(src), UTF32Mapping ) );
}

///Функция "очистки" значений HTML-аттрибутов
string HTMLEscapeValue(string src)
{	return replace( src, [ "<": "&lt;", ">": "&gt;", "\"": "&#34;", "\'": "&#39;", "&": "&amp;" ] );
}


string buildNormalPath(T...)(T args)
{
	import std.path: buildNormalizedPath;
	import std.algorithm: endsWith;

	string result = buildNormalizedPath(args);

	static if( args.length > 0 )
	{
		//Возвращаем на место слэш в конце пути, который выкидывает стандартная библиотека
		if( result.length > 1 && args[$-1].endsWith("/") && !result.endsWith("/") )
			result ~= '/';
	}

	return result;
}

Tuple!(
	string, "userError",
	string, "details"
)
makeErrorMsg(Throwable error)
{
	import std.typecons: Tuple;
	import std.conv: to;
	import trifle.backtrace: getBacktrace;

	typeof(return) res;

	string debugInfo = "\r\nIn module " ~ error.file ~ ":" ~ error.line.text ~ ". Backtrace:\r\n" ~ getBacktrace(error).to!string;
	res.details = error.msg ~ debugInfo;
	debug res.userError = res.details;
	else res.userError = error.msg;

	return res;
}

auto errorToJSON(Throwable ex)
{
	import std.json: JSONValue;
	import trifle.backtrace: getBacktrace;

	return JSONValue([
		"code": JSONValue(1), // Пока не знаю откуда мне брать код ошибки... Пусть будет 1
		"message": JSONValue(ex.msg),
		"data": JSONValue([
			"file": JSONValue(ex.file),
			"line": JSONValue(ex.line),
			"backtrace": JSONValue(getBacktrace(ex))
		])
	]);
}

import std.typecons: Tuple;
Tuple!(
	string, "mimeType",
	string, "key",
	string, "value"
)
parseContentType(string contentType)
{
	import std.algorithm: findSplit;
	import std.uni: toLower;

	typeof(return) res;
	auto splitCT = contentType.findSplit("; ");
	res.mimeType = splitCT[0]; // Получаем MIME-тип содержимого

	string charsetOrBoundary = splitCT[2];
	auto charsetSpl = charsetOrBoundary.findSplit("=");
	res.key = charsetSpl[0]; // Здесь может быть charset или boundary
	res.value = charsetSpl[1]; // Кодировка или значение для boundary
	return res;
}


