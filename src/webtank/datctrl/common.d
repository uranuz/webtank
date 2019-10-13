module webtank.datctrl.common;

import webtank.datctrl.consts;

mixin template GetStdJSONFormatImpl()
{
	import std.json: JSONValue;
	import webtank.datctrl.consts;
	JSONValue getStdJSONFormat() inout
	{
		JSONValue jValues;
		jValues[WT_KEY_FIELD_INDEX] = _keyFieldIndex; // Номер ключевого поля
		jValues[WT_TYPE_FIELD] = WT_TYPE_RECORDSET; // Тип данных - набор записей

		//Образуем JSON-массив форматов полей
		JSONValue[] jFieldFormats;
		jFieldFormats.length = _dataFields.length;

		foreach( i, field; _dataFields ) {
			jFieldFormats[i] = field.getStdJSONFormat();
		}
		jValues[WT_FORMAT_FIELD] = jFieldFormats;

		return jValues;
	}
}

mixin template GetStdJSONDataImpl()
{
	import std.json: JSONValue;
	JSONValue getStdJSONData(size_t index) inout
	{
		JSONValue[] recJSON;
		recJSON.length = _dataFields.length;
		foreach( i, dataField; _dataFields ) {
			recJSON[i] = dataField.getStdJSONValue(index);
		}
		return JSONValue(recJSON);
	}
}

mixin template RecordSetToStdJSONImpl()
{
	import std.json: JSONValue;
	import webtank.datctrl.consts;
	JSONValue toStdJSON() inout
	{
		auto jValues = this.getStdJSONFormat();

		JSONValue[] jData;
		jData.length = this.length;

		foreach( i; 0..this.length ) {
			jData[i] = this.getStdJSONData(i);
		}

		jValues[WT_DATA_FIELD] = jData;
		jValues[WT_TYPE_FIELD] = WT_TYPE_RECORDSET;

		return jValues;
	}
}

mixin template GetStdJSONFieldFormatImpl()
{
	import std.json: JSONValue;
	import webtank.datctrl.consts;

	/// Сериализации формата поля в std.json
	JSONValue getStdJSONFormat() inout
	{
		JSONValue res;

		static if( isEnumFormat!(FormatType) ) {
			res = _enumFormat.toStdJSON();
		} else {
			import std.traits: isIntegral, isFloatingPoint, isArray, isAssociativeArray, isSomeString;
			res[WT_TYPE_FIELD] = getFieldTypeString!ValueType; // Вывод типа поля
			res[WT_DLANG_TYPE_FIELD] = ValueType.stringof; // D-шный тип поля

			static if( isIntegral!(ValueType) || isFloatingPoint!(ValueType) ) {
				res[WT_SIZE_FIELD] = ValueType.sizeof; // Размер чисел в байтах
			}

			static if( isArray!ValueType && !isSomeString!ValueType ) {
				import std.range: ElementType;
				res[WT_VALUE_TYPE_FIELD] = getFieldTypeString!(ElementType!ValueType);
			} else static if( isAssociativeArray!(ValueType) ) {
				import std.traits: TKeyType = KeyType, TValueType = ValueType;
				res[WT_VALUE_TYPE_FIELD] = getFieldTypeString!(TValueType!ValueType);
				res[WT_KEY_TYPE_FIELD] = getFieldTypeString!(TKeyType!ValueType);
			}
		}
		res[WT_NAME_FIELD] = _name; // Вывод имени поля

		return res;
	}
}

mixin template GetStdJSONFieldValueImpl()
{
	import std.json: JSONValue;
	JSONValue getStdJSONValue(size_t index) inout
	{
		import webtank.common.std_json: toStdJSON;
		if( !isNull(index) ) {
			return get(index).toStdJSON();
		}
		return JSONValue(null);
	}
}

string getFieldTypeString(T)()
{
	import std.traits;
	import std.datetime: SysTime, DateTime, Date;

	static if( is(T: void) ) {
		return "void";
	} else static if( is(T: bool) ) {
		return "bool";
	} else static if( isIntegral!(T) ) {
		return "int";
	} else static if( isFloatingPoint!(T) ) {
		return "float";
	} else static if( isSomeString!(T) ) {
		return "str";
	} else static if( isArray!(T) ) {
		return "array";
	} else static if( isAssociativeArray!(T) ) {
		return "assocArray";
	} else static if( is( Unqual!T == SysTime ) || is( Unqual!T == DateTime) ) {
		return "dateTime";
	} else static if( is( Unqual!T == Date ) ) {
		return "date";
	} else {
		return "<unknown>";
	}
}

import std.json: JSONValue, JSONType;
import webtank.common.optional: Optional;

void _extractFromJSON(
	ref JSONValue jContainer,
	ref JSONValue jFormat,
	ref JSONValue jData,
	ref string type,
	ref Optional!size_t kfi
) {
	import std.exception: enforce;
	import std.algorithm: canFind;
	import std.conv: to;

	enforce(jContainer.type == JSONType.object, `Expected JSON object as container serialized data!!!`);
	auto jFormatPtr = WT_FORMAT_FIELD in jContainer;
	auto jDataPtr = WT_DATA_FIELD in jContainer;
	auto jTypePtr = WT_TYPE_FIELD in jContainer;
	auto jKfiPtr = WT_KEY_FIELD_INDEX in jContainer;

	enforce(jFormatPtr, `Expected "` ~ WT_FORMAT_FIELD ~ `" field in container serialized data!!!`);
	enforce(jDataPtr, `Expected "` ~ WT_DATA_FIELD ~ `" field in container serialized data!!!`);
	enforce(jTypePtr, `Expected "` ~ WT_TYPE_FIELD ~ `" field in container serialized data!!!`);
	enforce(jKfiPtr, `Expected "` ~ WT_KEY_FIELD_INDEX ~ `" field in container serialized data!!!`);

	enforce(jFormatPtr.type == JSONType.array, `Format field "` ~ WT_FORMAT_FIELD ~ `" must be JSON array!!!`);
	enforce(jDataPtr.type == JSONType.array, `Data field "` ~ WT_DATA_FIELD ~ `" must be JSON array!!!`);
	enforce(jTypePtr.type == JSONType.string, `Type field "` ~ WT_TYPE_FIELD ~ `" must be JSON string!!!`);
	enforce(
		[JSONType.uinteger, JSONType.integer].canFind(jKfiPtr.type),
		`Expected integer as "` ~ WT_KEY_FIELD_INDEX ~ `" field in container JSON`);

	jFormat = (*jFormatPtr);
	jData = (*jDataPtr);
	type = jTypePtr.str;
	kfi = (
		jKfiPtr.type == JSONType.uinteger?
		jKfiPtr.uinteger.to!size_t:
		jKfiPtr.integer.to!size_t
	);
}

auto _makeRecordFieldIndex(JSONValue jFormat)
{
	import std.exception: enforce;

	size_t[string] fieldToIndex;
	foreach( size_t index, JSONValue jField; jFormat )
	{
		enforce(jField.type == JSONType.object, `RecordSet serialized field format must be object!!!`);
		auto jNamePtr = WT_NAME_FIELD in jField;
		enforce(jNamePtr !is null, `RecordSet serialized field format must have "` ~ WT_NAME_FIELD ~ `" field`);
		enforce(jNamePtr.type == JSONType.string, `RecordSet serialized field name must be JSON string!!!`);
		enforce(jNamePtr.str !in fieldToIndex, `RecordSet field name must be unique!!!`);
		fieldToIndex[jNamePtr.str] = index;
	}
	return fieldToIndex;
}

import webtank.datctrl.iface.data_field: IBaseWriteableDataField;
void _fillDataIntoRec(RecordFormatT)(
	IBaseWriteableDataField[] dataFields,
	JSONValue jRecord,
	size_t recIndex,
	size_t[string] fieldToIndex
) {
	import std.exception: enforce;
	import std.conv: text;

	enum size_t expectedFieldCount = RecordFormatT.tupleOfNames.length;

	enforce(jRecord.type == JSONType.array, `Record serialized data expected to be JSON array!!!`);
	enforce(jRecord.array.length >= expectedFieldCount,
		`Not enough items in serialized Record. Expected ` ~ expectedFieldCount.text ~ ` got ` ~ jRecord.array.length.text);
	foreach( formatFieldIndex, name; RecordFormatT.names )
	{
		enforce(name in fieldToIndex, `Expected field in record with name: ` ~ name);
		dataFields[formatFieldIndex].fromStdJSONValue(jRecord[fieldToIndex[name]], recIndex);
	}
}