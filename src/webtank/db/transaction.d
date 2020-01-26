module webtank.db.transaction;

import webtank.db.iface.database: IDatabase;
import webtank.db.iface.transaction: IDBTransaction;
import webtank.db.consts: DBMSType, WriteMode, IsolationLevel;

IDBTransaction makeTransaction(IDatabase db, WriteMode mode = WriteMode.ReadWrite, IsolationLevel level=IsolationLevel.ReadCommitted)
{
	import webtank.db.postgresql.transaction: PostgreSQLTransaction;

	import std.exception: enforce;

	switch( db.type )
	{
		case DBMSType.PostgreSQL:
			return new PostgreSQLTransaction(db, mode, level);
		default: break;
	}
	enforce(false, `Unsupported database type for transaction`);
	return null; // Suppress no return error
}
