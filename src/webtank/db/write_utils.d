module webtank.db.write_utils;

// Используется в качестве аттрибута для указания названия поля в базе данных
struct DBField
{
	string dbName;
}

import std.json: JSONValue;
public import webtank.common.std_json.to: FieldSerializer;
void maybeDBSerializeMethod(string name, T)(ref T dValue, ref JSONValue[string] jArray)
{
	import webtank.common.std_json.to: toStdJSON;
	static if( name != `dbSerializeMode` )
	{
		import std.traits: getUDAs;
		alias dbAttrs = getUDAs!( __traits(getMember, dValue, name), DBField );
		static if( dbAttrs.length == 0 ) {
			jArray[name] = toStdJSON( __traits(getMember, dValue, name) );
		} else static if( dbAttrs.length == 1 ) {
			string serializedName = dValue.dbSerializeMode? dbAttrs[0].dbName: name;
			jArray[serializedName] = toStdJSON( __traits(getMember, dValue, name) );
		} else static assert(false, `Expected 0 or 1 DBField attributes count!!!`);
	}
}

/++
	Шаблон, который генерирует код, выполняющий обход полей типа Undefable для переменной c именем recordVar.
	Поля со значением isUndef = true игнорируются при этом.
	Для каждого из указанных полей, выполняется код, переданный в параметре payload
	`Миксин` определяет ряд символов для использования:
		fieldName - имя поля
		FieldSymbol - `символ` поля. Символ - это не тип и не значение
		FieldType - тип поля
		dbFieldName - имя поля в базе данных (если задано через аттрибут DBField)
		field - значение поля
+/
template WalkFields(string recordVar, string payload)
{
	import std.format: format;
	enum string WalkFields = (q{
		import std.meta: AliasSeq;
		import std.traits: getUDAs;
		import webtank.common.optional: isUndefable;
		
		foreach( fieldName; AliasSeq!(__traits(allMembers, typeof(%1$s))) )
		{
			alias FieldSymbol = __traits(getMember, %1$s, fieldName);
			alias FieldType = typeof(FieldSymbol);
			static if( isUndefable!FieldType )
			{
				alias DBFieldAttrs = getUDAs!(FieldSymbol, DBField);
				static assert(
					DBFieldAttrs.length < 2,
					`Expected one or zero DBField attrs on struct field`);
				static if( DBFieldAttrs.length ) {
					enum string dbFieldName = DBFieldAttrs[0].dbName;
				} else {
					enum string dbFieldName = null;
				}

				auto field = __traits(getMember, record, fieldName);
				if( field.isUndef )
					continue;

				%2$s
			}
		}
	}).format(recordVar, payload);
}

import webtank.db: IDatabase;
import webtank.common.optional: Optional;

Optional!size_t insertOrUpdateTableByNum(
	IDatabase db,
	string table,
	string[] fieldNames,
	string[] fieldValues,
	Optional!size_t num = Optional!size_t(),
	string[] safeFieldNames = null,
	string[] safeFieldValues = null
) {
	import std.exception: enforce;
	import std.range: empty, iota, chain;
	import std.algorithm: map;
	import std.array: join;
	import std.conv: text, to;

	import webtank.db.iface.query_result: IDBQueryResult;

	enforce(fieldNames.length == fieldValues.length, `Field names and values count must be equal`);
	enforce(safeFieldNames.length == safeFieldValues.length, `Safe field names and values count must be equal`);
	if( fieldNames.empty && safeFieldNames.empty ) {
		return Optional!size_t();
	}
	string fieldNamesJoin = chain(fieldNames, safeFieldNames).map!( (it) => `"` ~ it ~ `"` ).join(", ");
	auto placeholders = iota(1, fieldNames.length + 1).map!( (it) => `$` ~ it.text )();
	string values = chain(placeholders, safeFieldValues).join(`, `);

	string queryStr;
	if( num.isSet ) {
		queryStr = `update "` ~ table ~ `" set(` ~ fieldNamesJoin ~ `) = ROW(` ~ values ~ `) where num = ` ~ num.text ~ ` returning num`;
	} else {
		queryStr = `insert into "` ~ table ~ `" (` ~ fieldNamesJoin ~ `) values(` ~ values ~ `) returning num`;
	}

	IDBQueryResult queryRes = db.queryParamsArray(queryStr, fieldValues);
	return Optional!size_t(queryRes.get(0, 0, "0").to!size_t);
}