module webtank.db.utils;

// Замена одинарных кавычек на две в строках при передаче строковых данных напрямую в теле запроса к PostgreSQL.
// Настоятельно рекомендуется не передавать данные в теле запроса, а формировать параметризованный запрос!!!
// Но если сделать это не выходит, то рекомендуется использовать этот метод, а не делать replace по-месту!!
// При использовании спец. метода гораздо легче найти места в коде, где используется это экранирование
string PGEscapeStr(string srcStr, string quoteSubst = "''" )
{
	import std.array: replace;

	return srcStr.replace("'", "''");
}

// То же что и выше, но для замены двойных кавычек на две в идентификаторах сущностей в PostgreSQL
string PGEscapeIdent(string srcStr, string quoteSubst = "''" )
{
	import std.array: replace;

	return srcStr.replace(`"`, `""`);
}