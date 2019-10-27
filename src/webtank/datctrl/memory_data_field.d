module webtank.datctrl.memory_data_field;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.enum_format;

import webtank.datctrl.consts;

class MemoryDataField(FormatType): IWriteableDataField!(FormatType)
{
	import webtank.common.optional: Optional;
	import std.exception: enforce;

	alias ValueType = DataFieldValueType!(FormatType);

protected:
	string _name;
	Optional!(ValueType)[] _values;
	bool _isNullable;

public:

	static if( isEnumFormat!(FormatType) )
	{
		this(
			string fieldName,
			FormatType enumFormat,
			Optional!(ValueType)[] values = null,
			bool isNullable = true
		) {
			_name = fieldName;
			_enumFormat = enumFormat;
			_values = values;
			_isNullable = isNullable;
		}

		protected FormatType _enumFormat;
	} else {
		this(
			string fieldName,
			Optional!(ValueType)[] values = null,
			bool isNullable = true
		) {
			_name = fieldName;
			_values = values;
			_isNullable = isNullable;
		}
	}

	override {
		size_t length() @property inout {
			return _values.length;
		}

		string name() @property inout {
			return _name;
		}

		bool isNullable() @property inout {
			return _isNullable;
		}

		bool isWriteable() @property inout {
			return true;
		}

		static immutable OUT_OF_BOUNDS = `Data field value index out of bounds!!!`;
		bool isNull(size_t index) inout
		{
			enforce(index < _values.length, OUT_OF_BOUNDS);
			return isNullable && _values[index].isNull;
		}

		string getStr(size_t index)
		{
			import std.conv: text;
			enforce(index < _values.length, OUT_OF_BOUNDS);
			return isNull(index)? null: _values[index].text;
		}

		string getStr(size_t index, string defaultValue)
		{
			import std.conv: text;
			enforce(index < _values.length, OUT_OF_BOUNDS);
			return isNull(index)? defaultValue: _values[index].text;
		}

		import webtank.datctrl.common;
		mixin GetStdJSONFieldFormatImpl;
		mixin GetStdJSONFieldValueImpl;

		inout(ValueType) get(size_t index) inout {
			return _values[index].value;
		}

		inout(ValueType) get(size_t index, ValueType defaultValue) inout
		{
			enforce(index < _values.length, OUT_OF_BOUNDS);
			return cast(inout)(cast(ValueType) (isNull(index)? defaultValue: _values[index].value));
		}

		static if( isEnumFormat!(FormatType) )
		{
			inout(FormatType) enumFormat() inout {
				return _enumFormat;
			}
		}

		void set(ValueType value, size_t index)
		{
			enforce(index < _values.length, OUT_OF_BOUNDS);
			_values[index] = value;
		}

		void nullify(size_t index)
		{
			enforce(index < _values.length, OUT_OF_BOUNDS);
			_values[index] = null;
		}

		void isNullable(bool value) @property {
			_isNullable = value;
		}

		void addItems(size_t count, size_t index = size_t.max)
		{
			import std.array: insertInPlace;
			import std.range: repeat;
			if( index == size_t.max ) {
				index = _values.length? _values.length - 1: 0;
			}
			_values.insertInPlace(index, Optional!ValueType().repeat(count));
		}

		void addItems(ValueType[] values, size_t index = size_t.max)
		{
			import std.array: insertInPlace;
			import std.algorithm: map;
			if( index == size_t.max ) {
				index = _values.length? _values.length - 1: 0;
			}
			_values.insertInPlace(index, values.map!((it) => Optional!ValueType(it)));
		}

		import std.json: JSONValue, JSONType;
		void fromStdJSONValue(JSONValue jValue, size_t index)
		{
			enforce(index < _values.length, OUT_OF_BOUNDS);
			
			import webtank.common.std_json.from: fromStdJSON;
			if( jValue.type == JSONType.null_ ) {
				_values[index] = null;
			} else {
				_values[index] = fromStdJSON!ValueType(jValue);
			}
		}
	} //override
}

IBaseWriteableDataField[] makeMemoryDataFields(RecordFormatT)(RecordFormatT format)
{
	IBaseWriteableDataField[] dataFields;
	foreach( fieldName; RecordFormatT.tupleOfNames )
	{
		alias FieldFormatDecl = RecordFormatT.getFieldFormatDecl!(fieldName);
		alias DataFieldType = MemoryDataField!FieldFormatDecl;
		alias fieldIndex = RecordFormatT.getFieldIndex!(fieldName);

		bool isNullable = format.nullableFlags.get(fieldName, true);

		static if( isEnumFormat!(FieldFormatDecl) )
		{
			alias enumFieldIndex = RecordFormatT.getEnumFormatIndex!(fieldName);
			dataFields ~= new DataFieldType(fieldName, format.enumFormats[enumFieldIndex], null, isNullable);
		} else {
			dataFields ~= new DataFieldType(fieldName, null, isNullable);
		}
	}
	return dataFields;
}

import std.json: JSONValue, JSONType;
import webtank.common.optional: Optional;

struct RecordSetFieldAccessor(ValueType)
{
	import std.exception: enforce;

	private JSONValue jData;
	private size_t fieldIndex;
	private size_t recordIndex = 0;

	this(JSONValue dat, size_t fi)
	{
		enforce(dat.type == JSONType.array, `Expected JSON array as record set data`);
		jData = dat;
		fieldIndex = fi;
	}

	Optional!ValueType front() @property
	{
		import std.exception: enforce;

		import webtank.common.std_json.from: fromStdJSON;

		enforce(!this.empty, `RecordSetFieldAccessor is empty`);

		JSONValue jRec = jData.array[recordIndex];
		enforce(jRec.type == JSONType.array, `Expected JSON array as record data`);
		enforce(fieldIndex < jRec.array.length, `Field index is out of bounds of JSON record`);
		JSONValue jVal = jRec.array[fieldIndex];

		return fromStdJSON!(Optional!ValueType)(jVal);
	}

	void popFront() {
		++recordIndex;
	}

	bool empty() @property {
		return recordIndex >= jData.array.length;
	}
}


IBaseWriteableDataField[] makeMemoryDataFieldsDyn(JSONValue jFormat, JSONValue jData)
{
	import std.exception: enforce;
	import std.algorithm: map, canFind;
	import std.array: array;
	import std.datetime: DateTime, Date;
	import std.typecons: tuple;
	import std.conv: to;

	enforce(jFormat.type == JSONType.array, `Expected JSON array of field formats`);
	enforce(jData.type == JSONType.array, `Expected JSON array of record or record set data`);

	IBaseWriteableDataField[] fields;
	foreach( size_t fieldIndex, JSONValue jField; jFormat.array )
	{
		auto jTypePtr = WT_TYPE_FIELD in jField;
		auto jNamePtr = WT_NAME_FIELD in jField;
		
		enforce(jTypePtr !is null, `Expected "` ~ WT_TYPE_FIELD ~ `" field in field format JSON`);
		enforce(jTypePtr.type == JSONType.string, `Field format field "` ~ WT_TYPE_FIELD ~ `" expected to be a string`);

		enforce(jNamePtr !is null, `Expected "` ~ WT_NAME_FIELD ~ `" field in field format JSON`);
		enforce(jNamePtr.type == JSONType.string, `Field format field "` ~ WT_NAME_FIELD ~ `" expected to be a string`);

		Optional!size_t theSize;
		if( auto jSizePtr = WT_SIZE_FIELD in jField )
		{
			enforce(
				[JSONType.uinteger, JSONType.integer].canFind(jSizePtr.type),
				`Expected integer as "` ~ WT_SIZE_FIELD ~ `" field`);
			theSize = (
				jSizePtr.type == JSONType.uinteger?
				jSizePtr.uinteger.to!size_t:
				jSizePtr.integer.to!size_t
			);
		}

		import std.meta: AliasSeq;
		string fieldName = jNamePtr.str;
		alias fArgs = AliasSeq!(fields, fieldName, fieldIndex, jData);

		switch( jTypePtr.str )
		{
			case `bool`: {
				_addField!bool(fArgs);
				break;
			}
			case `int`:
			{
				_addSizedField!(int, byte, short, long)(fArgs, theSize);
				break;
			}
			case `float`:
			{
				_addSizedField!(double, float, real)(fArgs, theSize);
				break;
			}
			case `str`: {
				_addField!string(fArgs);
				break;
			}
			case `array`:
			{
				string arrayKind;
				if( auto jArrayKindPtr = WT_VALUE_TYPE_FIELD in jField ) {
					enforce(jArrayKindPtr.type == JSONType.string, `Expected string as "` ~ WT_VALUE_TYPE_FIELD ~ `" field`);
					arrayKind = jArrayKindPtr.str;
				}
				switch( arrayKind )
				{
					case `bool`: {
						_addField!(bool[])(fArgs);
						break;
					}
					case `int`:
					{
						_addSizedField!(int[], byte[], short[], long[])(fArgs, theSize);
						break;
					}
					case `float`: {
						_addSizedField!(double[], float[], real[])(fArgs, theSize);
						break;
					}
					case `str`: {
						_addField!(string[])(fArgs);
						break;
					}
					default: enforce(false, `Unsupported kind of array field`);
				}
				break;
			}
			case `assocArray`: {
				enforce(false, `Assoc array kind type of field is not supported yet`);
				break;
			}
			case `dateTime`: {
				_addField!DateTime(fArgs);
				break;
			}
			case `date`: {
				_addField!Date(fArgs);
				break;
			}
			default: enforce(false, `Unsupported type of field`);
		}
	}
	return fields;
}

private template GetBaseSizedType(SizedType)
{
	import std.traits: isArray;
	import std.range: ElementType;

	static if( isArray!(SizedType) ) {
		alias GetBaseSizedType = ElementType!(SizedType);
	} else {
		alias GetBaseSizedType = SizedType;
	}
}

private void _addSizedField(SizedTypes...)(
	IBaseWriteableDataField[] fields,
	string fieldName,
	size_t fieldIndex,
	JSONValue jData,
	Optional!size_t theSize
) {
	import std.exception: enforce;
	import std.conv: to;

	// Берем первый тип из списка как тип по умолчанию
	alias DefaultType = GetBaseSizedType!(SizedTypes[0]);

	if( theSize.isNull )
	{
		// Ничо не сказано - берем тип по дефолту
		theSize = DefaultType.sizeof;
	}
	size_switch:
	switch( theSize.value )
	{
		static foreach( SizedType; SizedTypes )
		{
			case GetBaseSizedType!(SizedType).sizeof:
			{
				_addField!SizedType(fields, fieldName, fieldIndex, jData);
				break size_switch;
			}
		}
		default: enforce(false, `Expected type from list: ` ~ SizedTypes.stringof ~ `, but got: ` ~ theSize.value.to!string);
	}
}

private void _addField(FieldType)(
	ref IBaseWriteableDataField[] fields,
	string name,
	size_t fieldIndex,
	JSONValue jData
) {
	import std.array: array;
	auto valRange = RecordSetFieldAccessor!FieldType(jData, fieldIndex);
	fields ~= new MemoryDataField!FieldType(name, valRange.array);
}

unittest
{
	import webtank.datctrl.iface.data_field;
	import webtank.datctrl.record_format;
	auto recFormat = RecordFormat!(
		PrimaryKey!(size_t, "num"),
		string, "name"
	)();
	IBaseWriteableDataField[] dataFields = makeMemoryDataFields(recFormat);
	assert(dataFields.length == 2);

	foreach( dataField; dataFields ) {
		dataField.addItems(1);
		assert(dataField.length == 1);
	}
}

unittest
{
	import std.json: parseJSON;

	string rawRSStr = `
	"f": [
		{"n": "familyName", "t": "str"},
		{"n": "age", "t": "int", "sz": "1"},
		{"n": "birthDate", "t": "date"},
		{"n": "cost", "t": "float", "sz": "2"}
	],
	"d": [
		["Vasya Petushok", 28, "08.07.1989", 167.5],
		[null, null, null, null]
	]`;

	JSONValue jRS = parseJSON(rawRSStr);
	auto fields = makeMemoryDataFieldsDyn(jRS["f"], jRS["d"]);
}