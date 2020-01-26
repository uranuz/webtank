module webtank.db.consts;

/++
$(LANG_EN	Enumerated type representing types of database
	management system (DBMS)
)
$(LANG_RU Перечислимый тип, представляющий типы систем
	управления базами данных (СУБД)
)
+/
enum DBMSType {PostgreSQL, MySQL, Firebird}; //Вроде как на будущее

enum DBLogInfoType
{
	info,
	warn,
	error
};

enum IsolationLevel {
	Serializeable, RepeatableRead, ReadCommitted, ReadUncommitted
}

enum WriteMode {
	ReadOnly, ReadWrite
}

enum string AUTH_DB = `authDB`;