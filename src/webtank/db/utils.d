module webtank.db.utils;

//Функция возвращает переданную строку с заменой экранированными кавычками для БД postgresql
string PGEscapeStr(string srcStr, string quoteSubst = "''" )
{
	import std.utf: toUTF32, toUTF8;

	dstring result;
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