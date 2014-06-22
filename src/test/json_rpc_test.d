module webtank.test.json_rpc_test;

import std.conv, std.string, std.file, std.stdio, std.json;

import webtank.datctrl._import, webtank.db._import;

immutable asyncHandlersPath = "/dyn/handlers/";
immutable thisPagePath = asyncHandlersPath ~ "xhr_test";

alias FieldType ft;

void main()
{	string connStr = "dbname=postgres host=localhost user=postgres password=postgres";
	auto dbase = new DBPostgreSQL(connStr);
	assert( dbase.isConnected );

	auto bookRecFormat = RecordFormat!(ft.IntKey, "Ключ", ft.Str, "Название", ft.Str, "Автор", ft.Str, "Жанр", ft.Int, "Цена", ft.Bool, "Скидка", ft.Bool, "Переплет")();
	
	string query = `select * from book`;
	auto book_rs = dbase.query(query).getRecordSet(bookRecFormat);
	auto rec = book_rs.front;
	auto jBookRS = getJSONValue(rec);
	writeln( toJSON( &jBookRS ) );
// 	foreach( rec; book_rs )
// 	{	write( rec.getStr("Цена") );
// // 		writeln( " - " ~ typeid( rec.getS"Цена"() ).to!string );
// 	}
	
	
}