module webtank.tests.json_rpc_test;

import std.conv, std.string, std.file, std.stdio, std.json, std.datetime, std.typecons;

import webtank.datctrl, webtank.db;

enum Publishment: string { Hud_lit = "Худ. литература",  Binom = "Бином" };

static immutable PublishmentEnumFormat = EnumFormat!(Publishment, false)([ Publishment.Hud_lit, Publishment.Binom ]);


void main()
{	string connStr = "dbname=postgres host=localhost user=postgres password=postgres";
	auto dbase = new DBPostgreSQL(connStr);
	assert( dbase.isConnected );

	auto bookRecFormat = RecordFormat!(
		PrimaryKey!(int), "Ключ", 
		string, "Название", 
		dstring, "Автор", 
		wstring, "Жанр", 
		int, "Цена", 
		bool, "Скидка", 
		bool, "Переплет",
		typeof(PublishmentEnumFormat), "Издательство"
	)(
		null,
		tuple(PublishmentEnumFormat)
	);
	
	writeln("enumFormats is:\r\n", bookRecFormat.enumFormats);
	
	writeln("TestPoint 1");
	
	string query = `select * from book`;
	auto book_rs = dbase.query(query).getRecordSet(bookRecFormat);
	auto rec1 = book_rs.front;
	auto jBookRS = rec1.toStdJSON();
	writeln( toJSON( &jBookRS ) );
	
	writeln("TestPoint 2");
	writeln( book_rs[0] );
	
	try 
	{
		foreach( rec; book_rs )
		{	write( rec.getStr("Жанр") );
			writeln( " - " ~ typeid( rec.get!"Жанр"() ).to!string );
		}
	}
	catch( Throwable e )
	{
		writeln(e.msg);
	}
	
	writeln("TestPoint 3");
	
	auto indRec = new WriteableRecord!( typeof(bookRecFormat) )();
	
	indRec.set!("Автор")("Вася");
	indRec.set!("Цена")(100500);
	writeln( indRec.get!("Цена") );
	writeln( Object.sizeof );
}