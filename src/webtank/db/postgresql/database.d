module webtank.db.postgresql.database;

import webtank.db.iface.database: IDatabase, DBLogerMethod, DBLogInfo;

///Класс работы с СУБД PostgreSQL
class DBPostgreSQL: IDatabase
{
	import webtank.db.postgresql.bindings;
	import webtank.db.postgresql.consts: ConnStatusType;
	import webtank.db.postgresql.query_result: PostgreSQLQueryResult;

	import webtank.db.iface.query_result: IDBQueryResult;
	import webtank.db.consts: DBLogInfoType, DBMSType;
	import webtank.db.exception: DBException;

	import std.string: toStringz;
	import std.conv: to;

protected:
	PGconn* _conn;
	string _connStr;
	DBLogerMethod _logerMethod;

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

			IDBQueryResult res;
			scope(exit) {
				_logRequest(cast(string) queryStr, null, res);
			}

			_checkConnection();

			//Выполняем запрос
			PGresult* pgRes = PQexec(_conn, toStringz(queryStr));
			return (res = new PostgreSQLQueryResult(this, pgRes));
		}

		IDBQueryResult queryParamsArray(const(char)[] queryStr, string[] params)
		{
			import std.conv: to;
			IDBQueryResult res;
			scope(exit) {
				_logRequest(cast(string) queryStr, params, res);
			}

			const(char*)[] cParams;
			int[] paramLengths;

			foreach( param; params )
			{
				cParams ~= param is null? null: param.toStringz();
				paramLengths ~= param.length.to!int; // Documentation says that PG ignores it, but still pass it
			}

			_checkConnection();

			PGresult* pgResult = PQexecParams(
				_conn,
				toStringz(queryStr),
				cParams.length.to!int,
				null, //paramTypes: auto
				cParams.ptr,
				paramLengths.ptr,
				null, //paramFormats: text
				0 //resultFormat: text
			);

			return (res = new PostgreSQLQueryResult(this, pgResult));
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

	package void _logMsg(lazy string msg)
	{
		if( _logerMethod ) {
			_logerMethod(DBLogInfo(msg, DBLogInfoType.info));
		}
	}

	package void _warningMsg(lazy string msg)
	{
		if( _logerMethod ) {
			_logerMethod(DBLogInfo(msg, DBLogInfoType.warn));
		}
	}

	package void _errorMsg(lazy string msg)
	{
		if( _logerMethod ) {
			_logerMethod(DBLogInfo(msg, DBLogInfoType.error));
		}
	}

	static immutable PARAM_LOG_SIZE = 200; // Ограничиваем логируемый объем данных параметра запроса
	string _printParams(string[] params)
	{
		import std.string: join;
		import std.algorithm: map;
		if( params.length == 0 ) {
			return ` none`;
		}
		return "\n" ~ params.map!(
			(it) => (it.length > PARAM_LOG_SIZE? it[0..PARAM_LOG_SIZE] ~ `...`: it)
		).join("\n") ~ "\n";
	}

	void _logRequest(string queryString, string[] params, IDBQueryResult res)
	{
		import std.conv: text;
		_logMsg(
			queryString
			~ "\nParams:" ~ _printParams(params)
			~ "\nResult:" ~ (
				res !is null? (` tuples: ` ~ res.recordCount.text ~ `, fields: ` ~ res.fieldCount.text): ` none`
			)
		);
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