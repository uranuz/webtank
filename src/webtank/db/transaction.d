module webtank.db.transaction;

import webtank.db.database;

interface IDBTransaction
{
	void commit();
	void rollback();
	string exportSnapshot();
}

enum IsolationLevel {
	Serializeable, RepeatableRead, ReadCommitted, ReadUncommitted
}

enum WriteMode {
	ReadOnly, ReadWrite
}

IDBTransaction makeTransaction(IDatabase db, WriteMode mode = WriteMode.ReadWrite, IsolationLevel level=IsolationLevel.ReadCommitted)
{
	switch( db.type )
	{
		case DBMSType.PostgreSQL:
			return new PostgreSQLTransaction(db, mode, level);
		default: break;
	}
	assert(false, `Unsupported database type for transaction`);
}


class PostgreSQLTransaction: IDBTransaction
{
	private IDatabase _db;
	
	this(IDatabase db, WriteMode mode = WriteMode.ReadWrite, IsolationLevel level=IsolationLevel.ReadCommitted)
	{
		assert(db, `Db reference is null!!!`);
		_db = db;
		assert(_db.type == DBMSType.PostgreSQL, `Expected PostgreSQL db connection!!!`);

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