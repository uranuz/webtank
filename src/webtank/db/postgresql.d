module webtank.db.postgresql;

import std.string, std.exception, std.conv;

import webtank.db.database;

extern (C)
{
	alias uint Oid;

	struct PGconn;
	struct PGresult;

	PGconn *PQconnectdb(const char *conninfo); // New connection to the database server.

	/++ Submits a command to the server and waits for the result. +/
	PGresult* PQexec(PGconn *conn, const char *command);

	ExecStatusType PQresultStatus(const PGresult* res);

	PGresult *PQexecParams(
		PGconn *conn,
		const char *command,
		int nParams,
		const Oid *paramTypes,
		const char** paramValues,
		const int *paramLengths,
		const int *paramFormats,
		int resultFormat
	);

	/++ Closes the connection to the server. Also frees memory used by the PGconn object. +/
	void PQfinish(PGconn *conn);

	int PQntuples(const PGresult *res); // Number of rows in table
	int PQnfields(const PGresult *res); // Number of columns in table

	/++ Returns name of column with specified number or NULL if number is out of range +/
	char *PQfname(const PGresult *res, int column_number);

	/++ Returns column number with specified or -1 if the given name does not match any column +/
	int PQfnumber(const PGresult *res, const char *column_name);

	/++ Returns a single field value of one row of a PGresult. Row and column numbers start at 0 +/
	char *PQgetvalue(const PGresult *res, int row_number, int column_number);

	/++ Tests a field for a null value. Row and column numbers start at 0. +/
	int PQgetisnull(const PGresult *res, int row_number, int column_number);

	/++ Returns the actual length of a field value in bytes. Row and column numbers start at 0. +/
	int PQgetlength(const PGresult *res, int row_number, int column_number);

	void PQclear(PGresult *res); // Frees the storage associated with a PGresult.

	/++ Returns the error message most recently generated by an operation on the connection. +/
	char *PQerrorMessage(const PGconn *conn);

	// Returns the status of the connection.
	int PQstatus(const PGconn *conn);
}

//--- Some PostgreSQL enum values
enum ConnStatusType
{
	CONNECTION_OK,
	CONNECTION_BAD
}

enum ExecStatusType
{
	PGRES_EMPTY_QUERY = 0, /* empty query string was executed */
	PGRES_COMMAND_OK, /* a query command that doesn't return anything was executed properly by the backend */
	PGRES_TUPLES_OK, /* a query command that returns tuples was executed properly by the backend, PGresult contains the result tuples */
	PGRES_COPY_OUT, /* Copy Out data transfer in progress */
	PGRES_COPY_IN, /* Copy In data transfer in progress */
	PGRES_BAD_RESPONSE, /* an unexpected response was recv'd from the backend */
	PGRES_NONFATAL_ERROR, /* notice or warning message */
	PGRES_FATAL_ERROR, /* query failed */
	PGRES_COPY_BOTH, /* Copy In/Out data transfer in progress */
	PGRES_SINGLE_TUPLE /* single tuple from larger resultset */
}
//---

///Класс работы с СУБД PostgreSQL
class DBPostgreSQL : IDatabase
{
protected:
	PGconn* _conn;
	string _connStr;
	DBLogerMethod _logerMethod;

	void _logMsg(string msg)
	{
		if( _logerMethod ) {
			_logerMethod(DBLogInfo(msg, DBLogInfoType.info));
		}
	}

	void _warningMsg(string msg)
	{
		if( _logerMethod ) {
			_logerMethod(DBLogInfo(msg, DBLogInfoType.warn));
		}
	}

	void _errorMsg(string msg)
	{
		if( _logerMethod ) {
			_logerMethod(DBLogInfo(msg, DBLogInfoType.error));
		}
	}

	// Проверка и установка соединения с БД
	private void _checkConnection()
	{
		if( !this.isConnected ) {
			_warningMsg(`No connection to database established. Attempt to (re)connect...`);
			this.connect(_connStr);
		}
	}


public:
	//Конструктор объекта, принимает строку подключения как параметр
	this(string connStr, DBLogerMethod logerMethod = null) //Конструктор объекта, принимает строку подключения
	{
		_logerMethod = logerMethod;
		_connStr = connStr;
	}

	override {
		//Ф-ция подключения к БД
		bool connect(string connStr)
		{
			if( connStr.length && _connStr != connStr )
			{
				// Попытка подключиться к другой БД
				_connStr = connStr;
				this.disconnect(); // Отключаемся от старой БД
			}

			_conn = PQconnectdb(toStringz(_connStr));
			if( !this.isConnected ) {
				static immutable errorMsg = `Cannot establish database connection!`;
				_errorMsg(errorMsg);
				throw new DBException(errorMsg);
			}
			_logMsg(`Database connection established`);
			return true;
		}

		//Проверить, что подключены
		bool isConnected() @property {
			return PQstatus(_conn) == ConnStatusType.CONNECTION_OK;
		}

		//Запрос к БД, строка запроса в качестве параметра
		//Возвращает объект унаследованный от интерфейса результата запроса
		IDBQueryResult query(const(char)[] queryStr)
		{
			import std.algorithm: canFind;
			import std.exception: assumeUnique;

			_logMsg(cast(string) queryStr);
			_checkConnection();

			//Выполняем запрос
			PGresult* res = PQexec(_conn, toStringz(queryStr));

			return new PostgreSQLQueryResult(this, res);
		}

		//Получение строки с недавней ошибкой
		string lastErrorMessage() {
			return PQerrorMessage(_conn).to!string;
		}

		//Тип СУБД
		DBMSType type() @property {
			return DBMSType.PostgreSQL;
		}

		//Отключиться от БД
		void disconnect()
		{
			if( _conn !is null )
			{
				_warningMsg(`Disconnecting from database...`);
				PQfinish(_conn);
				_conn = null;
			}
		}
	}

	package PGconn* rawPGConn() @property {
		return _conn;
	}

	~this()
	{
		if (_conn !is null)
		{
			PQfinish(_conn);
			_conn = null;
		}
	}

}

private immutable ExecStatusType[] goodStatuses = [
	ExecStatusType.PGRES_EMPTY_QUERY,
	ExecStatusType.PGRES_COMMAND_OK,
	ExecStatusType.PGRES_TUPLES_OK
];

///Результат запроса для СУБД PostgreSQL
class PostgreSQLQueryResult: IDBQueryResult
{
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


///Функция преобразования параметров в строковое представление для PostgreSQL
string toPGString(T)(T value)
{
	import std.traits: isNumeric, isSomeString, isArray;
	import std.datetime: DateTime, SysTime;
	import std.conv: to;
	import std.range: ElementType;
	import webtank.common.optional: isOptional;

	static if( is(T == typeof(null)) )
	{
		return `null`;
	}
	else static if( isOptional!T )
	{
		return value.isSet? toPGString(value.value): `null`;
	}
	else static if( is(T == bool) || isNumeric!(T) )
	{
		return value.to!string;
	}
	else static if( isSomeString!(T) )
	{
		return value.to!string;
	}
	else static if( is(T == SysTime) || is(T == DateTime) )
	{
		return value.toISOExtString();
	}
	else static if( isArray!(T) )
	{
		alias ElemType = ElementType!T;
		string arrayData;
		foreach( i, elem; value )
		{
			if( arrayData.length > 0 ) {
				arrayData ~= ",";
			}
			arrayData ~= toPGString(elem);
		}
		return "ARRAY[" ~ arrayData ~ "]";
	}
	else static assert(false, `Unexpected type of parameter to safely represent in PostgreSQL query`);
}

///Реализация запроса параметризованного кортежем для PostgreSQL
PostgreSQLQueryResult queryParamsPostgreSQL(TL...)(DBPostgreSQL database, string expression, ref TL params)
{
	import std.string: toStringz;
	import std.conv: to;
	import std.exception: enforce;
	enforce!DBException(database !is null, `Expected DBPostgreSQL instance!`);

	const(char*)[] cParams;
	int[] paramLengths;

	foreach( param; params )
	{
		string strParam = param.toPGString(); // Assure that there is zero symbol
		cParams ~= strParam.toStringz();
		paramLengths ~= strParam.length.to!int; // Documentation says that PG ignores it, but still pass it
	}

	database._logMsg(expression);
	database._checkConnection();

	PGresult* pgResult = PQexecParams(
		database.rawPGConn,
		toStringz(expression),
		cParams.length.to!int,
		null, //paramTypes: auto
		cParams.ptr,
		paramLengths.ptr,
		null, //paramFormats: text
		0 //resultFormat: text
	);

	return new PostgreSQLQueryResult(database, pgResult);
}
