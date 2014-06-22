module webtank.datctrl_test;

import std.typetuple, std.typecons, std.stdio, std.conv;

import   webtank.datctrl.data_field, webtank.datctrl.record_format, webtank.datctrl.record, webtank.datctrl.record_set;
import webtank.db.database_field, webtank.db.datctrl_joint, webtank.db.postgresql, webtank.db.database;

void main()
{	
	alias FieldType ft;
	
	string connStr = "dbname=postgres host=localhost user=postgres password=postgres";
	auto dbase = new DBPostgreSQL(connStr);
	assert( dbase.isConnected );
	
	auto bookRecFormat = RecordFormat!(ft.IntKey, "Ключ", ft.Str, "Название", ft.Str, "Автор", ft.Str, "Жанр", ft.Int, "Цена", ft.Bool, "Скидка", ft.Bool, "Переплет")();
	
	auto book_rs = dbase
	/+.execQueryTuple(+/ .createQueryTuple(
		`select * from book where hardcover = $1 and discount = $2;`, 
		false, true
	).exec()
	.getRecordSet(bookRecFormat);

// 	auto queryStr = `select * from book where hardcover = $1 and discount = $3`;
// 	auto book_rs = dbase.queryParams(queryStr, ["true", "false"]).getRecordSet(bookRecFormat);
	foreach( rec; book_rs )
	{	writeln( rec.getStr("Цена"), "  ", rec.getStr("Автор"), "  ", rec.getStr("Название") );
// 		writeln(  );
	}
}