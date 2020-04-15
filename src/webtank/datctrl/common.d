module webtank.datctrl.common;

mixin template GetStdJSONFormatImpl()
{
	import std.json: JSONValue;
	import webtank.datctrl.consts;
	JSONValue getStdJSONFormat() inout
	{
		JSONValue jValues;
		jValues[SrlField.keyFieldIndex] = _keyFieldIndex; // Номер ключевого поля
		jValues[SrlField.type] = SrlEntityType.recordSet; // Тип данных - набор записей

		//Образуем JSON-массив форматов полей
		JSONValue[] jFieldFormats;
		jFieldFormats.length = _dataFields.length;

		foreach( i, field; _dataFields ) {
			jFieldFormats[i] = field.getStdJSONFormat();
		}
		jValues[SrlField.format] = jFieldFormats;

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

		jValues[SrlField.data] = jData;
		jValues[SrlField.type] = SrlEntityType.recordSet;

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
			res[SrlField.type] = getFieldTypeString!ValueType; // Вывод типа поля
			res[SrlField.dLangType] = ValueType.stringof; // D-шный тип поля

			static if( isIntegral!(ValueType) || isFloatingPoint!(ValueType) ) {
				res[SrlField.size] = ValueType.sizeof; // Размер чисел в байтах
			}

			static if( isArray!ValueType && !isSomeString!ValueType ) {
				import std.range: ElementType;
				res[SrlField.valueType] = getFieldTypeString!(ElementType!ValueType);
			} else static if( isAssociativeArray!(ValueType) ) {
				import std.traits: TKeyType = KeyType, TValueType = ValueType;
				res[SrlField.valueType] = getFieldTypeString!(TValueType!ValueType);
				res[SrlField.keyType] = getFieldTypeString!(TKeyType!ValueType);
			}
		}
		res[SrlField.name] = _name; // Вывод имени поля

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

string getFieldTypeString(QualT)()
{
	import std.traits: Unqual, isIntegral, isFloatingPoint, isSomeString, isArray, isAssociativeArray;
	import std.datetime: SysTime, DateTime, Date, TimeOfDay;
	import webtank.datctrl.consts: SrlFieldType;

	alias T = Unqual!QualT;

	static if( is(T: void) ) {
		return SrlFieldType.void_;
	} else static if( is(T: bool) ) {
		return SrlFieldType.boolean;
	} else static if( isIntegral!(T) ) {
		return SrlFieldType.integer;
	} else static if( isFloatingPoint!(T) ) {
		return SrlFieldType.floating;
	} else static if( isSomeString!(T) ) {
		return SrlFieldType.string;
	} else static if( isArray!(T) ) {
		return SrlFieldType.array;
	} else static if( isAssociativeArray!(T) ) {
		return SrlFieldType.assocArray;
	} else static if( is(T == SysTime) || is(T == DateTime) ) {
		return SrlFieldType.dateTime;
	} else static if( is(T == Date) ) {
		return SrlFieldType.date;
	} else static if( is(T == TimeOfDay) ) {
		return SrlFieldType.time;
	} else {
		return SrlFieldType.unknown;
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
	import webtank.datctrl.consts: SrlField;
	import std.exception: enforce;
	import std.algorithm: canFind;
	import std.conv: to;

	enforce(jContainer.type == JSONType.object, `Expected JSON object as container serialized data!!!`);
	auto jFormatPtr = SrlField.format in jContainer;
	auto jDataPtr = SrlField.data in jContainer;
	auto jTypePtr = SrlField.type in jContainer;
	auto jKfiPtr = SrlField.keyFieldIndex in jContainer;

	enforce(jFormatPtr, `Expected "` ~ SrlField.format ~ `" field in container serialized data!!!`);
	enforce(jDataPtr, `Expected "` ~ SrlField.data ~ `" field in container serialized data!!!`);
	enforce(jTypePtr, `Expected "` ~ SrlField.type ~ `" field in container serialized data!!!`);
	enforce(jKfiPtr, `Expected "` ~ SrlField.keyFieldIndex ~ `" field in container serialized data!!!`);

	enforce(jFormatPtr.type == JSONType.array, `Format field "` ~ SrlField.format ~ `" must be JSON array!!!`);
	enforce(jDataPtr.type == JSONType.array, `Data field "` ~ SrlField.data ~ `" must be JSON array!!!`);
	enforce(jTypePtr.type == JSONType.string, `Type field "` ~ SrlField.type ~ `" must be JSON string!!!`);
	enforce(
		[JSONType.uinteger, JSONType.integer].canFind(jKfiPtr.type),
		`Expected integer as "` ~ SrlField.keyFieldIndex ~ `" field in container JSON`);

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
	import webtank.datctrl.consts: SrlField;
	import std.exception: enforce;

	size_t[string] fieldToIndex;
	foreach( size_t index, JSONValue jField; jFormat )
	{
		enforce(jField.type == JSONType.object, `RecordSet serialized field format must be object!!!`);
		auto jNamePtr = SrlField.name in jField;
		enforce(jNamePtr !is null, `RecordSet serialized field format must have "` ~ SrlField.name ~ `" field`);
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