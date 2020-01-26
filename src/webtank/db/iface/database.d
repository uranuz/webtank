module webtank.db.iface.database;

import webtank.db.consts: DBLogInfoType, DBMSType;
import webtank.db.iface.query_result: IDBQueryResult;

struct DBLogInfo
{
	string msg;
	DBLogInfoType type;
}

alias DBLogerMethod = void delegate(DBLogInfo logInfo);

/++
$(LANG_EN Base interface for database)
$(LANG_RU Базовый интерфейс для базы данных)
+/
interface IDatabase
{
	/++
	$(LANG_EN
		Connects to database using connection string. Returns true if
		connection is succesful or false if not
	)
	$(LANG_RU
		Подключается к базе данных, используя строку подключения.
		Возвращает true при успешном подключении или false в противном
		случае
	)
	+/
	bool connect(string connStr);

	/++
	$(LANG_EN Property returns true if connection establised)
	$(LANG_RU Свойство возвращает true при установленном подключении)
	+/
	bool isConnected() @property;

	/++
	$(LANG_EN
		Method executes query to database represented by $(D_PARAM queryStr).
		Returns database query result $(D IDBQueryResult)
	)
	$(LANG_RU
		Метод выполняет запрос к базе данных представленный строкой запроса
		$(D_PARAM queryStr). Возвращает результат запроса $(D IDBQueryResult)
	)
	+/
	IDBQueryResult query(const(char)[] queryStr);
	//DBStatus getStatus() @property; //Подробнее узнать как дела у базы

	IDBQueryResult queryParamsArray(const(char)[] queryStr, string[] params);

	/++
	$(LANG_EN
		Property returns last error message when executing query. Returns
		null if there is no error
	)
	$(LANG_RU
		Свойство возвращает строку с сообщением о последней ошибке.
		Возвращает пустое значение (null), если ошибок нет
	)
	+/
	string lastErrorMessage() @property; //Прочитать последнюю ошибку
	//string getVersionInfo();

	/++
	$(LANG_EN Property returns type of database)
	$(LANG_RU Свойство возвращает тип базы данных)
	+/
	DBMSType type() @property;

	/++
	$(LANG_EN Method disconnects from database server)
	$(LANG_RU Метод отключения от сервера баз данных)
	+/
	void disconnect();
}