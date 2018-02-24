module webtank.db.transaction;

import webtank.db.database;

interface IDBTransaction
{
	void commit();
	void rollback();
}

enum IsolationLevel {
	Serializeable, RepeatableRead, ReadCommitted, ReadUncommitted
}

enum WriteMode {
	ReadOnly, ReadWrite
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
}