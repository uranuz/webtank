module webtank.db.factory;

import webtank.db.iface.factory: IDatabaseFactory;

// Фабрика для создания экземпляров соединений с базой. Каждый раз создает новой подключение
// Позволяет получить соединение с бахой по заранее сформированному конфигу
// Для получения соединения достаточно знать условный идентификатор базы
class DBFactory: IDatabaseFactory
{
	import webtank.db.iface.database: IDatabase, DBLogerMethod;

	import std.exception: enforce;
private:
	string[string] _dbConnStrings;
	DBLogerMethod _logerMethod;

public:
	this(string[string] dbConnStrings, DBLogerMethod logerMethod = null)
	{
		_dbConnStrings = dbConnStrings;
		_logerMethod = logerMethod;
	}

	IDatabase getDB(string dbID)
	{
		import webtank.db.postgresql.database: DBPostgreSQL;

		auto connStrPtr = dbID in _dbConnStrings;
		enforce(
			connStrPtr !is null && connStrPtr.length > 0,
			`Строка подключения к базе не найдена, либа пуста: ` ~ dbID);
		return new DBPostgreSQL(*connStrPtr, _logerMethod);
	}
}