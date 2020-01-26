module webtank.db.query_params;

import webtank.db.iface.database: IDatabase;
import webtank.db.iface.query_result: IDBQueryResult;

///Функция выполнения параметризованного запроса по кортежу параметров
IDBQueryResult queryParams(TL...)(IDatabase database, string expression, TL params)
{
	import webtank.db.postgresql.serialize: toPGString;
	import webtank.db.exception: DBException;
	import webtank.db.consts: DBMSType;

	import std.exception: enforce;
	import std.conv: to;

	enforce!DBException(database !is null, "Database connection object is null!!!");

	switch( database.type )
	{
		case DBMSType.PostgreSQL:
		{
			string[] strParams;
			foreach( param; params ) {
				strParams ~= param.toPGString(); // Assure that there is zero symbol
			}
			return database.queryParamsArray(expression, strParams);
		}
		default: break;
	}
	throw new DBException("queryParams is not implemented for: " ~ database.type.to!string);
}
