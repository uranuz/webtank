module webtank.db.per_thread_pool_mixin;

/*
	Инструкция:
	1. Добавить примесь в web-сервис
	2. Унаследовать сервис от IDatabaseFactory
	3. Позвать в конструкторе _initDBPool() после вычитки конфига и до использования баз данных
*/
mixin template DBPerThreadPoolMixin()
{
	import webtank.db.iface.factory: IDatabaseFactory;
	import webtank.db.iface.database: IDatabase;
	import webtank.db.factory: DBFactory;
	import webtank.db.per_thread_pool: DBPerThreadPool;

	IDatabaseFactory _db_pool;

	// Проинициализировать пул соединений с БД
	void _initDBPool() {
		_db_pool = new DBPerThreadPool(new DBFactory(this.dbConnStrings, &this.databaseLogerMethod));
	}

	override IDatabase getDB(string dbID) {
		return _db_pool.getDB(dbID);
	}
}