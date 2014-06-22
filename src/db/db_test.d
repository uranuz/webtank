module webtank.db.db_test;

import std.stdio;

//import webtank.db.database;
import webtank.db.postgresql;
import webtank.db.db_record_set;

import webtank.datctrl.record_format;
//import webtank.datctrl.record_set;




int main()
{	RecordFormat bookRecFormat;
	with(FieldType) {
	bookRecFormat = RecordFormat(
	[Int, Str, Str, Str, Int, Bool, Bool],
	["Ключ", "Название", "Автор", "Жанр", "Цена", "Есть скидка"/*, "Твёрдый переплёт"*/],
	[true, true, true, true, true, true, true], //Разрешение нулевого значения
	);
	}
	
	string connStr = "dbname=postgres host=localhost user=postgres password=postgres";
	auto dbase = new DBPostgreSQL(connStr);
	if (dbase.isConnected) writeln("Соединение с БД установлено");
	else  writeln("Ошибка соединения");
	
	auto response = /*cast(PostgreSQLQueryResult)*/ dbase.query(`select * from book`);
	auto resp2 = cast(PostgreSQLQueryResult) response;
	auto rs = response.toRecordSetByFormat(bookRecFormat);
	//writeln(rs[1][1].toStr);
	//writeln(resp2.getValue(0,1));
	writeln(rs[1]["Автор"].toStr());
	writeln(rs[0]["Ключ"].toStr());
	writeln(rs.getField(3).name);
	
	
	
	return 0;
}
