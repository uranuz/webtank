module webtank.db.database;

import std.conv;

/++
$(LOCALE_EN_US	Enumerated type representing types of database
	management system (DBMS)
)
$(LOCALE_RU_RU Перечислимый тип, представляющий типы систем
	управления базами данных (СУБД)
)
+/
enum DBMSType {PostgreSQL, MySQL, Firebird}; //Вроде как на будущее

/++
$(LOCALE_EN_US Base interface for database)
$(LOCALE_RU_RU Базовый интерфейс для базы данных)
+/
interface IDatabase ///Интерфейс БД
{
	/++
	$(LOCALE_EN_US
		Connects to database using connection string. Returns true if
		connection is succesful or false if not
	)
	$(LOCALE_RU_RU
		Подключается к базе данных, используя строку подключения.
		Возвращает true при успешном подключении или false в противном
		случае
	)
	+/
	bool connect(string connStr);

	/++
	$(LOCALE_EN_US Property returns true if connection establised)
	$(LOCALE_RU_RU Свойство возвращает true при установленном подключении)
	+/
	bool isConnected() @property;

	/++
	$(LOCALE_EN_US
		Method executes query to database represented by $(D_PARAM queryStr).
		Returns database query result $(D IDBQueryResult)
	)
	$(LOCALE_RU_RU
		Метод выполняет запрос к базе данных представленный строкой запроса
		$(D_PARAM queryStr). Возвращает результат запроса $(D IDBQueryResult)
	)
	+/
	IDBQueryResult query(const(char)[] queryStr);
	//DBStatus getStatus() @property; //Подробнее узнать как дела у базы

	/++
	$(LOCALE_EN_US
		Property returns last error message when executing query. Returns
		null if there is no error
	)
	$(LOCALE_RU_RU
		Свойство возвращает строку с сообщением о последней ошибке.
		Возвращает пустое значение (null), если ошибок нет
	)
	+/
	string lastErrorMessage() @property; //Прочитать последнюю ошибку
	//string getVersionInfo();

	/++
	$(LOCALE_EN_US Property returns type of database)
	$(LOCALE_RU_RU Свойство возвращает тип базы данных)
	+/
	DBMSType type() @property;

	/++
	$(LOCALE_EN_US Method disconnects from database server)
	$(LOCALE_RU_RU Метод отключения от сервера баз данных)
	+/
	void disconnect();
}

/++
$(LOCALE_EN_US Base interface for data base query result)
$(LOCALE_RU_RU Базовый интерфейс для результата запроса к базе данных)
+/
interface IDBQueryResult
{	/+DBMSType type() @property; //Снова тип СУБД+/
	/++
	$(LOCALE_EN_US Property returns record count in result)
	$(LOCALE_RU_RU Свойство возвращает количество записей в результате)
	+/
	size_t recordCount() @property;

	/++
	$(LOCALE_EN_US Property returns field count in result)
	$(LOCALE_RU_RU Свойство возвращает количество полей в результате)
	+/
	size_t fieldCount() @property;

	/++
	$(LOCALE_EN_US Method clears object and frees resources of result)
	$(LOCALE_RU_RU Метод очищает объект и освобождает ресурсы результата)
	+/
	void clear(); //Очистить объект

	/++
	$(LOCALE_EN_US
		Method returns name of field in result by field index $(D_PARAM index)
	)
	$(LOCALE_RU_RU
		Метод возвращает имя поля в результате по индексу поля $(D_PARAM index)
	)
	+/
	string getFieldName(size_t index);

	/++
	$(LOCALE_EN_US
		Method returns index of field in result by field name $(D_PARAM name)
	)
	$(LOCALE_RU_RU
		Метод возвращает номер поля в результате по имени поля $(D_PARAM name)
	)
	+/
	size_t getFieldIndex(string name);

	/++
	$(LOCALE_EN_US
		Method returns true if cell with field index $(D_PARAM fieldIndex) and
		record index $(D_PARAM recordIndex) is null or false otherwise
	)
	$(LOCALE_RU_RU
		Метод возвращает true, если ячейка с номером поля $(D_PARAM fieldIndex)
		и номером записи $(D_PARAM recordIndex) является пустой (null) или
		false в противном случае
	)
	+/
	bool isNull(size_t fieldIndex, size_t recordIndex);

	/++
	$(LOCALE_EN_US
		Method returns value of celll with field index $(D_PARAM fieldIndex) and
		record index $(D_PARAM recordIndex). If cell is null then behaviour is
		undefined
	)
	$(LOCALE_RU_RU
		Метод возвращает значение ячейки с номером поля $(D_PARAM fieldIndex)
		и номером записи $(D_PARAM recordIndex). Если ячейка пуста (null), то
		поведение не определено
	)
	+/
	string get(size_t fieldIndex, size_t recordIndex);

	/++
	$(LOCALE_EN_US
		Method returns value of celll with field index $(D_PARAM fieldIndex) and
		record index $(D_PARAM recordIndex). $(D_PARAM defaultValue) parameter
		sets return value when cell is null
	)
	$(LOCALE_RU_RU
		Метод возвращает значение ячейки с номером поля $(D_PARAM fieldIndex)
		и номером записи $(D_PARAM recordIndex). Параметр метода
		$(D_PARAM defaultValue) задает возвращаемое значение, если ячейка пуста (null)
	)
	+/
	string get(size_t fieldIndex, size_t recordIndex, string defaultValue);
}

/++
$(LOCALE_EN_US Exception class for database)
$(LOCALE_RU_RU Класс исключений при работе с БД)
+/
class DBException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

///Функция создания параметризованного запроса к БД
DBQuery createQuery( IDatabase database, string expression = null )
{	return DBQuery( database, expression );
}

///Функция создания параметризованого запроса по кортежу параметров
DBQuery createQueryTuple(TL...)( IDatabase database, string expression, TL params )
	//if( is( DB : IDatabase ) )
{	return DBQuery( database, expression, params );
}

///Функция выполнения параметризованного запроса по кортежу параметров
IDBQueryResult execQueryTuple(TL...)( IDatabase database, string expression, TL params )
	//if( is( DB : IDatabase ) )
{	import webtank.db.postgresql;
	if( database.type == DBMSType.PostgreSQL )
	{	auto dbase = cast(DBPostgreSQL) database;
		if( dbase is null )
			throw new DBException("Database connection object is null!!!");
			
		return execQueryTupleImpl( dbase, expression, params );
	}
	else
		throw new DBException("execQueryTuple function for database driver " ~ database.type.to!string ~ " is not implemented!!!");
	assert(0);
}

///Параметризованный запрос к базе данных
struct DBQuery
{	import webtank.db.postgresql;
	this( IDatabase database, string expression )
	{	_dbType = database.type;
		if( _dbType == DBMSType.PostgreSQL )
		{	auto dbase = cast(DBPostgreSQL) database;
			_pgQuery = PostgreSQLQuery(dbase, expression);
		}
		else
			_notImplementedError();
	}
	
	this(TL...)( IDatabase database, string expression, TL params )
	{	this( database, expression );
		setParamTuple(params);
	}
	
	///Метод устанавливает параметры запросов по кортежу значений
	///Существующие параметры полностью перезаписываются
	ref DBQuery setParamTuple(TL...)(TL params)
	{	clearParams();
		if( _dbType == DBMSType.PostgreSQL )
			_pgQuery.setParamTuple(params);
		else
			_notImplementedError();
		return this;
	}
	
	///Устанавливает param в качестве значения параметра с номером index
	ref DBQuery setParam(T)( uint index, T param )
	{	if( _dbType == DBMSType.PostgreSQL )
			_pgQuery.setParam(index, param);
		else
			_notImplementedError();
		return this;
	}
	
	///Выполняет сформированный запрос
	IDBQueryResult exec()
	{	if( _dbType == DBMSType.PostgreSQL )
			return _pgQuery.exec();
		else
			_notImplementedError();
		assert(0);
	}
	
	///Функция задаёт выражение запроса (с местозаполнителями для параметров)
	ref DBQuery setExpr( string expression )
	{	if( _dbType == DBMSType.PostgreSQL )
			_pgQuery.setExpr(expression);
		else
			_notImplementedError();
		return this;
	}
	
	///Стирает внутренний набор параметров
	ref DBQuery clearParams()
	{	if( _dbType == DBMSType.PostgreSQL )
			_pgQuery.clearParams();
		else
			_notImplementedError();
		return this;
	}
	
	private void _notImplementedError(string file = __FILE__, size_t line = __LINE__)
	{	throw new DBException("DBQuery for database driver " ~ _dbType.to!string ~ " is not implemented!!!", file, line);
	}
	
protected:
	union {
		PostgreSQLQuery _pgQuery;
	}
	DBMSType _dbType;
}