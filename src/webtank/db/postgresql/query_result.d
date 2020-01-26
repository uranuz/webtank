module webtank.db.postgresql.query_result;

import webtank.db.iface.query_result: IDBQueryResult;

import webtank.db.postgresql.consts: ExecStatusType;

private immutable ExecStatusType[] goodStatuses = [
	ExecStatusType.PGRES_EMPTY_QUERY,
	ExecStatusType.PGRES_COMMAND_OK,
	ExecStatusType.PGRES_TUPLES_OK
];

///Результат запроса для СУБД PostgreSQL
class PostgreSQLQueryResult: IDBQueryResult
{
	import webtank.db.postgresql.bindings;
	import webtank.db.postgresql.database: DBPostgreSQL;

	import webtank.db.exception: DBException;

	import std.exception: enforce;
	import std.conv: to;
	import std.string: toStringz;
	
protected:
	PGresult *_queryResult;
	DBPostgreSQL _database;

public:
	this(DBPostgreSQL db, PGresult* result)
	{
		_queryResult = result;
		_database = db;
		enforce(db !is null, `Expected DBPostgreSQL instance`);

		_testPostgresRes();
	}

	private void _testPostgresRes()
	{
		import std.algorithm: canFind;

		if( !goodStatuses.canFind(PQresultStatus(_queryResult)) )
		{
			string errorMsg = _database.lastErrorMessage;
			_database._errorMsg(errorMsg);
			throw new DBException(errorMsg);
		}
	}

	///ПЕРЕОПРЕДЕЛЕНИЕ ИНТЕРФЕЙСНЫХ ФУНКЦИЙ
	override {
		//Количество записей
		size_t recordCount() @property inout
		{
			if( _queryResult ) {
				return ( PQntuples(_queryResult) ).to!size_t;
			}
			return 0;
		}

		//Количество полей данных (столбцов)
		size_t fieldCount() @property inout
		{
			if( _queryResult ) {
				return ( PQnfields(_queryResult) ).to!size_t;
			}
			return 0;
		}

		//Очистить результат запроса
		void clear()
		{
			if( _queryResult !is null )
			{
				PQclear(_queryResult);
				_queryResult = null;
			}
		}


		//Получение имени поля по индексу
		string getFieldName(size_t index)
		{
			if( _queryResult )
				return ( PQfname( _queryResult, index.to!int ) ).to!string;
			else return null;
		}

		//Получение индекса поля по имени
		size_t getFieldIndex(string name)
		{
			if( _queryResult )
				return ( PQfnumber(_queryResult, toStringz(name) ) ).to!size_t;
			else return -1;
		}

		//Вернёт true, если поле пустое, и false иначе
		bool isNull(size_t fieldIndex, size_t recordIndex) inout
		{
			if( _queryResult !is null )
				return ( PQgetisnull(_queryResult, recordIndex.to!int, fieldIndex.to!int ) == 1 ) ? true : false;
			assert(0);
		}

		//Получение значения ячейки данных в виде строки
		//Неопределённое поведение, если ячейка пуста или её нет
		string get(size_t fieldIndex, size_t recordIndex) inout
		{
			if( _queryResult is null )
				return null;
			else
				return ( PQgetvalue(_queryResult, recordIndex.to!int, fieldIndex.to!int ) ).to!string;
		}

		//Получение значения ячейки данных в виде строки
		//Если ячейка пуста то вернёт значение параметра defaultValue
		string get(size_t fieldIndex, size_t recordIndex, string defaultValue) inout
		{
			if( isNull(fieldIndex, recordIndex) )
				return defaultValue;
			else
				return get(fieldIndex, recordIndex);
		}
	}

	~this() //Освобождаем результат запроса
	{
		if( _queryResult !is null )
		{
			PQclear(_queryResult);
			_queryResult = null;
		}
	}
}