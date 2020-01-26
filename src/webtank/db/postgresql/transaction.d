module webtank.db.postgresql.transaction;

import webtank.db.iface.transaction: IDBTransaction;

class PostgreSQLTransaction: IDBTransaction
{
	import webtank.db.consts: WriteMode, IsolationLevel, DBMSType;
	import webtank.db.iface.database: IDatabase;

	private IDatabase _db;

	this(IDatabase db, WriteMode mode = WriteMode.ReadWrite, IsolationLevel level=IsolationLevel.ReadCommitted)
	{
		import std.exception: enforce;

		enforce(db !is null, `Database reference is null`);
		_db = db;
		enforce(_db.type == DBMSType.PostgreSQL, `Expected PostgreSQL db connection`);

		string lvl;
		final switch(level) with(IsolationLevel)
		{
			case Serializeable: lvl = `SERIALIZABLE`; break;
			case RepeatableRead: lvl = `REPEATABLE READ`; break;
			case ReadCommitted: lvl = `READ COMMITTED`; break;
			case ReadUncommitted: lvl = `READ UNCOMMITTED`; break;
		}
		string readMode;
		final switch(mode) with(WriteMode)
		{
			case ReadOnly: readMode = `READ ONLY`; break;
			case ReadWrite: readMode = `READ WRITE`; break;
		}

		_db.query(`start transaction isolation level ` ~ lvl ~ ` ` ~ readMode);
	}

	override void commit()
	{
		_db.query(`commit`);
	}

	override void rollback()
	{
		_db.query(`rollback`);
	}

	override string exportSnapshot()
	{
		auto res = _db.query(`select pg_export_snapshot()`);
		return res.get(0, 0);
	}
}