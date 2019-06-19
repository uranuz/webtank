module webtank.datctrl.common;

mixin template GetStdJSONFormatImpl()
{
	import std.json: JSONValue;
	JSONValue getStdJSONFormat() inout
	{
		JSONValue jValues;
		jValues["kfi"] = _keyFieldIndex; // Номер ключевого поля
		jValues["t"] = "recordset"; // Тип данных - набор записей

		//Образуем JSON-массив форматов полей
		JSONValue[] jFieldFormats;
		jFieldFormats.length = _dataFields.length;

		foreach( i, field; _dataFields ) {
			jFieldFormats[i] = field.getStdJSONFormat();
		}
		jValues["f"] = jFieldFormats;

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
	JSONValue toStdJSON() inout
	{
		auto jValues = this.getStdJSONFormat();

		JSONValue[] jData;
		jData.length = this.length;

		foreach( i; 0..this.length ) {
			jData[i] = this.getStdJSONData(i);
		}

		jValues["d"] = jData;
		jValues["t"] = "recordset";

		return jValues;
	}
}

mixin template GetStdJSONFieldFormatImpl()
{

	import std.json: JSONValue;
	/// Сериализации формата поля в std.json
	JSONValue getStdJSONFormat() inout
	{
		JSONValue res;

		static if( isEnumFormat!(FormatType) ) {
			res = _enumFormat.toStdJSON();
		} else {
			import std.traits: isIntegral, isFloatingPoint, isArray, isAssociativeArray, isSomeString;
			res["t"] = getFieldTypeString!ValueType; // Вывод типа поля
			res["dt"] = ValueType.stringof; // D-шный тип поля

			static if( isIntegral!(ValueType) || isFloatingPoint!(ValueType) ) {
				res["sz"] = ValueType.sizeof; // Размер чисел в байтах
			}

			static if( isArray!ValueType && !isSomeString!ValueType ) {
				import std.range: ElementType;
				res["vt"] = getFieldTypeString!(ElementType!ValueType);
			} else static if( isAssociativeArray!(ValueType) ) {
				import std.traits: TKeyType = KeyType, TValueType = ValueType;
				res["vt"] = getFieldTypeString!(TValueType!ValueType);
				res["kt"] = getFieldTypeString!(TKeyType!ValueType);
			}
		}
		res["n"] = _name; // Вывод имени поля

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

import std.json: JSONValue, JSON_TYPE;
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

	enforce(jContainer.type == JSON_TYPE.OBJECT, `Expected JSON object as container serialized data!!!`);
	auto jFormatPtr = `f` in jContainer;
	auto jDataPtr = `d` in jContainer;
	auto jTypePtr = `t` in jContainer;
	auto jKfiPtr = `kfi` in jContainer;

	enforce(jFormatPtr, `Expected "f" field in container serialized data!!!`);
	enforce(jDataPtr, `Expected "d" field in container serialized data!!!`);
	enforce(jTypePtr, `Expected "t" field in container serialized data!!!`);
	enforce(jKfiPtr, `Expected "kfi" field in container serialized data!!!`);

	enforce(jFormatPtr.type == JSON_TYPE.ARRAY, `Format field "f" must be JSON array!!!`);
	enforce(jDataPtr.type == JSON_TYPE.ARRAY, `Data field "d" must be JSON array!!!`);
	enforce(jTypePtr.type == JSON_TYPE.STRING, `Type field "t" must be JSON string!!!`);
	enforce(
		[JSON_TYPE.UINTEGER, JSON_TYPE.INTEGER].canFind(jKfiPtr.type),
		`Expected integer as "kfi" field in container JSON`);

	jFormat = (*jFormatPtr);
	jData = (*jDataPtr);
	type = jTypePtr.str;
	kfi = (
		jKfiPtr.type == JSON_TYPE.UINTEGER?
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
		enforce(jField.type == JSON_TYPE.OBJECT, `RecordSet serialized field format must be object!!!`);
		auto jNamePtr = `n` in jField;
		enforce(jNamePtr !is null, `RecordSet serialized field format must have "n" field`);
		enforce(jNamePtr.type == JSON_TYPE.STRING, `RecordSet serialized field name must be JSON string!!!`);
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

	enforce(jRecord.type == JSON_TYPE.ARRAY, `Record serialized data expected to be JSON array!!!`);
	enforce(jRecord.array.length >= expectedFieldCount,
		`Not enough items in serialized Record. Expected ` ~ expectedFieldCount.text ~ ` got ` ~ jRecord.array.length.text);
	foreach( formatFieldIndex, name; RecordFormatT.names )
	{
		enforce(name in fieldToIndex, `Expected field in record with name: ` ~ name);
		dataFields[formatFieldIndex].fromStdJSONValue(jRecord[fieldToIndex[name]], recIndex);
	}
}