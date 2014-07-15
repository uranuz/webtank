module webtank.tests.json_rpc_test;

import std.conv, std.string, std.file, std.stdio, std.json, std.datetime;

import webtank.datctrl, webtank.db;

void main()
{	string connStr = "dbname=postgres host=localhost user=postgres password=postgres";
	auto dbase = new DBPostgreSQL(connStr);
	assert( dbase.isConnected );

	auto bookRecFormat = makeRecordFormat!(
		PrimaryKey!(int), "Ключ", 
		string, "Название", 
		dstring, "Автор", 
		wstring, "Жанр", 
		int, "Цена", 
		bool, "Скидка", 
		bool, "Переплет"
	)();
	
	string query = `select * from book`;
	auto book_rs = dbase.query(query).getRecordSet(bookRecFormat);
	//auto rec = book_rs.front;
	//auto jBookRS = rec.getStdJSON();
	//writeln( toJSON( &jBookRS ) );
	foreach( rec; book_rs )
	{	write( rec.getStr("Жанр") );
		writeln( " - " ~ typeid( rec.get!"Жанр"() ).to!string );
	}
	
	auto indRec = new IndependentRecord!( typeof(bookRecFormat) )();
	
	indRec.set!("Автор")("Вася");
	indRec.set!("Цена")(100500);
	writeln( indRec.get!("Цена") );
	writeln( Object.sizeof );
}