module webtank.history.common;

import std.datetime: DateTime;
import std.json: JSONValue;
import webtank.common.optional: Optional, Undefable;

enum HistoryRecordKind: ubyte
{
	Update = 0, // Обновление записи (передана вся запись)
	Insert = 1, // Вставка новой записи
	UpdatePartial = 2, // Обновление записи (переданы изменения)
	Delete = 3 // Удаление записи
}

struct HistoryRecordData
{
	string tableName;
	Optional!size_t recordNum;
	JSONValue data;
	Undefable!size_t userNum;
	Undefable!DateTime time_stamp; // Must be in UTC
	string actionUUID;
	HistoryRecordKind recordKind;
}

struct HistoryActionData
{
	string uuid;
	string parentUUID;
	string description;
	Undefable!size_t userNum;
	DateTime time_stamp;
}

struct RecordHistoryFilter
{
	size_t num;
	string objectName;
}