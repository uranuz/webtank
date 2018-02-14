 module webtank.net.utils;

 import std.utf, std.conv;

//Функция возвращает переданную строку с заменой экранированными кавычками для БД postgresql
string PGEscapeStr(string srcStr, string quoteSubst = "''" )
{	dstring result;
	immutable dQuoteSubst = toUTF32(quoteSubst);
	auto str = toUTF32(srcStr);
	size_t i = 0;
	size_t lastQuotePos = size_t.max;
	for( ; i < str.length; i++ )
	{	if( str[i] == '\'' )
		{	result ~= str[ (lastQuotePos + 1) .. i ] ~ dQuoteSubst ;
			lastQuotePos = i;
		}
	}
	result ~= str[ (lastQuotePos + 1) .. $ ];
	return toUTF8(result);
}


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

auto makeErrorMsg(Throwable error)
{
	import std.typecons: Tuple;
	import std.conv: text;
	Tuple!(string, "userError", string, "details") res;
	
	string debugInfo = "\r\nIn module " ~ error.file ~ ":" ~ error.line.text ~ ". Traceback:\r\n" ~ error.info.text;
	res.details = error.msg ~ debugInfo;
	debug res.userError = res.details;
	else res.userError = error.msg;

	return res;
}