module webtank.db.per_thread_pool;

import webtank.db.iface.factory: IDatabaseFactory;

// Тривиальный пул соединений с базами данных
// На каждый поток, который обратился к пулу создается соединение с БД с указанным идентификатором и удерживается в пуле
class DBPerThreadPool: IDatabaseFactory
{
	import webtank.db.iface.database: IDatabase;

	import core.thread: ThreadID, Thread;
	import core.sync.mutex: Mutex;
	import std.exception: enforce;

private:
	Mutex _mutex;
	IDatabaseFactory _factory;
	IDatabase[string][ThreadID] _dbs;

public:
	this(IDatabaseFactory factory)
	{
		_mutex = new Mutex(); // Мьютекс для синхронизации многопоточного доступа к пулу
		enforce(factory !is null, `Ожидалась фабрика баз данных`);
		_factory = factory; // Фабрика, которая непостредственно создает соединения, но не кэширует их
	}

	IDatabase getDB(string dbID)
	{
		synchronized(_mutex)
		{
			// TODO: Наверно, это не очень эффективный вариант,
			// когда синхронизация накладывается в том числе на получение существующего соединения из пула.
			// Нужно доработать этот код
			ThreadID thisTid = Thread.getThis().id;
			auto threadDBSPtr = thisTid in _dbs;
			if( threadDBSPtr is null )
			{
				_dbs[thisTid] = [dbID: _createDB(dbID)];
				threadDBSPtr = thisTid in _dbs;
			}
			auto dbPtr = dbID in (*threadDBSPtr);
			if( dbPtr is null )
			{
				(*threadDBSPtr)[dbID] = _createDB(dbID);
				dbPtr = dbID in (*threadDBSPtr);
			}
			return (*dbPtr);
		}
	}

	IDatabase _createDB(string dbID)
	{
		auto newDB = _factory.getDB(dbID);
		enforce(newDB !is null, `Не вышло получить базу от нижележащей фабрики!`);
		return newDB;
	}
}