module webtank.datctrl.memory_data_field;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.enum_format;

class MemoryDataField(FormatType): IWriteableDataField!(FormatType)
{
	import webtank.common.optional: Optional;
	import std.exception: enforce;

	alias ValueType = DataFieldValueType!(FormatType);

protected:
	string _name;
	Optional!(ValueType)[] _values;
	bool _isNullable;
	

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

		import std.json: JSONValue, JSON_TYPE;
		void fromStdJSONValue(JSONValue jValue, size_t index)
		{
			enforce(index < _values.length, OUT_OF_BOUNDS);
			
			import webtank.common.std_json.from: fromStdJSON;
			if( jValue.type == JSON_TYPE.NULL ) {
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

import std.json: JSONValue, JSON_TYPE;
import webtank.common.optional: Optional;

struct RecordSetFieldAccessor(ValueType)
{
	import std.exception: enforce;

	private JSONValue jData;
	private size_t fieldIndex;
	private size_t recordIndex = 0;

	this(JSONValue dat, size_t fi)
	{
		enforce(jData.type == JSON_TYPE.ARRAY, `Expected JSON array as record set data`);
		jData = dat;
		fieldIndex = fi;
	}

	Optional!ValueType front() @property
	{
		import std.traits: isIntegral, isFloatingPoint, isSomeString, isDynamicArray;
		import std.conv: to;
		import std.algorithm: canFind;
		import std.datetime: Date, DateTime;
		import std.range: ElementType;

		enforce(!this.empty, `RecordSetFieldAccessor is empty`);

		JSONValue jRec = jData.array[recordIndex];
		enforce(jRec.type == JSON_TYPE.ARRAY, `Expected JSON array as record data`);
		enforce(fieldIndex < jRec.array.length, `Field index is out of bounds of JSON record`);
		JSONValue jVal = jRec.array[fieldIndex];

		Optional!ValueType res;
		if( jVal.type == JSON_TYPE.NULL ) {
			return res;
		}

		static if( is(ValueType: bool) )
		{
			enforce([JSON_TYPE.TRUE, JSON_TYPE.FALSE].canFind(jVal.type), `Expected boolean`);
			res = jVal.boolean;
		}
		else static if( isIntegral!ValueType )
		{
			enforce([JSON_TYPE.INTEGER, JSON_TYPE.UINTEGER].canFind(jVal.type), `Expected integer`);
			res = jVal.type == JSON_TYPE.INTEGER? jVal.integer.to!ValueType: jVal.uinteger.to!ValueType;
		}
		else static if( isFloatingPoint!ValueType )
		{
			enforce(jVal.type == JSON_TYPE.FLOAT, `Expected floating point`);
			res = jVal.floating.to!ValueType;
		}
		else static if( isSomeString!ValueType )
		{
			enforce(jVal.type == JSON_TYPE.STRING, `Expected string`);
			res = jVal.str.to!ValueType;
		}
		else static if( isDynamicArray!ValueType )
		{
			alias Elem = ElementType!ValueType;
			enforce(jVal.type == JSON_TYPE.ARRAY, `Expected array`);
			ValueType items;
			foreach( JSONValue arrElem; jVal.array )
			{
				static if( is(Elem : bool) )
				{
					enforce([JSON_TYPE.TRUE, JSON_TYPE.FALSE].canFind(arrElem.type), `Expected bool array element`);
					items ~= arrElem.boolean;
				}
				else static if( isIntegral!Elem )
				{
					enforce([JSON_TYPE.INTEGER, JSON_TYPE.UINTEGER].canFind(arrElem.type), `Expected integer array element`);
					items ~= arrElem.type == JSON_TYPE.INTEGER? arrElem.integer.to!Elem: arrElem.uinteger.to!Elem;
				}
				else static if( isFloatingPoint!Elem )
				{
					enforce(jVal.type == JSON_TYPE.FLOAT, `Expected floating point array element`);
					items ~= arrElem.floating.to!Elem;
				}
				else static if( isSomeString!Elem )
				{
					enforce(jVal.type == JSON_TYPE.STRING, `Expected string point array element`);
					items ~= arrElem.str.to!Elem;
				}
				else
					static assert(false, `Unexpected array element type`);
			}
			res = items;
		}
		else static if( is(ValueType : Date) )
		{
			enforce(jVal.type == JSON_TYPE.ARRAY, `Expected date string`);
			res = Date.fromISOExtString(jVal.str);
		}
		else static if( is(ValueType : DateTime) )
		{
			enforce(jVal.type == JSON_TYPE.ARRAY, `Expected date and time string`);
			res = DateTime.fromISOExtString(jVal.str);
		}
		else
			static assert(false, `Unexpected ValueType`);
		return res;
	}

	void popFront() {
		++recordIndex;
	}

	bool empty() @property {
		return recordIndex < jData.array.length;
	}
}


IBaseWriteableDataField[] makeMemoryDataFieldsDyn(JSONValue jFormat, JSONValue jData)
{
	import std.exception: enforce;
	import std.algorithm: map, canFind;
	import std.array: array;
	import std.datetime: DateTime, Date;
	import std.meta: AliasSeq;

	enforce(jFormat.type == JSON_TYPE.ARRAY, `Expected JSON array of field formats`);
	enforce(jData.type == JSON_TYPE.ARRAY, `Expected JSON array of record or record set data`);

	IBaseWriteableDataField[] fields;
	foreach( size_t fieldIndex, JSONValue jField; jFormat.array )
	{
		auto jTypePtr = `t` in jField;
		auto jNamePtr = `n` in jField;
		
		enforce(jTypePtr !is null, `Expected "t" field in field format JSON`);
		enforce(jTypePtr.type == JSON_TYPE.STRING, `Field format field "t" expected to be a string`);

		enforce(jNamePtr !is null, `Expected "n" field in field format JSON`);
		enforce(jNamePtr.type == JSON_TYPE.STRING, `Field format field "n" expected to be a string`);

		string typeStr = jTypePtr.str;
		string fieldName = jNamePtr.str;
		Optional!size_t theSize;
		if( auto jSizePtr = `sz` in jField ) {
			enforce(jSizePtr.type == JSON_TYPE.UINTEGER, `Expected integer as "sz" field`);
			theSize = jSizePtr.uinteger;
		}

		switch( typeStr )
		{
			case `bool`: {
				_addField!bool(fields, fieldName, fieldIndex, jData);
				break;
			}
			case `int`:
			{
				if( theSize.isNull ) {
					theSize = int.sizeof;
				}
				switch( theSize.value )
				{
					foreach( IntType; AliasSeq!(byte, int, long) ) {
						case IntType.sizeof: {
							_addField!IntType(fields, fieldName, fieldIndex, jData);
							break;
						}
					}
					default: enforce(false, `Unsupported size of integer field`);
				}
				break;
			}
			case `float`:
			{
				if( theSize.isNull ) {
					theSize = double.sizeof;
				}
				switch( theSize.value )
				{
					foreach( FloatType; AliasSeq!(float, double, real) ) {
						case FloatType.sizeof: {
							_addField!FloatType(fields, fieldName, fieldIndex, jData);
							break;
						}
					}
					default: enforce(false, `Unsupported size of float field`);
				}
				break;
			}
			case `str`: {
				_addField!string(fields, fieldName, fieldIndex, jData);
				break;
			}
			case `array`:
			{
				string arrayKind;
				if( auto jArrayKindPtr = "vt" in jField ) {
					enforce(jArrayKindPtr.type == JSON_TYPE.STRING, `Expected string as "vt" field`);
					arrayKind = jArrayKindPtr.str;
				}
				switch( arrayKind )
				{
					case `bool`: {
						_addField!(bool[])(fields, fieldName, fieldIndex, jData);
						break;
					}
					case `int`: {
						_addField!(int[])(fields, fieldName, fieldIndex, jData);
						break;
					}
					case `float`: {
						_addField!(float[])(fields, fieldName, fieldIndex, jData);
						break;
					}
					case `str`: {
						_addField!(string[])(fields, fieldName, fieldIndex, jData);
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
				_addField!DateTime(fields, fieldName, fieldIndex, jData);
				break;
			}
			case `date`: {
				_addField!Date(fields, fieldName, fieldIndex, jData);
				break;
			}
			default: enforce(false, `Unsupported type of field`);
		}
	}
	return fields;
}

private void _addField(FieldType)(
	ref IBaseWriteableDataField[] fields,
	string name,
	size_t fieldIndex,
	JSONValue jData
) {
	import std.array: array;
	auto valRange = RecordSetFieldAccessor!FieldType(jData, fieldIndex);
	fields ~= new MemoryDataField!(FieldType)(name, valRange.array);
}

private JSONValue _getArrayItem(JSONValue jData, size_t index)
{
	import std.exception: enforce;
	enforce(jData.type == JSON_TYPE.ARRAY, `Expected JSON array of record or record set data`);
	enforce(index < jData.array.length, `Index of JSON array is out of bounds`);
	return jData[index];
}



unittest
{
	import webtank.datctrl.iface.data_field;
	import webtank.datctrl.record_format;
	auto recFormat = RecordFormat!(
		PrimaryKey!size_t, "num",
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