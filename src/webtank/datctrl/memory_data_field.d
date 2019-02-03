module webtank.datctrl.memory_data_field;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.enum_format;

class MemoryDataField(FormatType): IWriteableDataField!(FormatType)
{
	alias ValueType = DataFieldValueType!(FormatType);

protected:
	string _name;
	ValueType[] _values;
	bool[] _nullFlags;
	bool _isNullable;
	import std.exception: enforce;

	static if( isEnumFormat!(FormatType) )
	{
		this(
			string fieldName,
			FormatType enumFormat,
			ValueType[] values = null,
			bool isNullable = true,
			bool[] nullFlags = null
		) {
			_name = fieldName;
			_enumFormat = enumFormat;
			_values = values;
			_isNullable = isNullable;
			_nullFlags = nullFlags;
		}

		protected FormatType _enumFormat;
	} else {
		this(
			string fieldName,
			ValueType[] values = null,
			bool isNullable = true,
			bool[] nullFlags = null
		) {
			_values = values;
			_nullFlags = nullFlags;
			_name = fieldName;
			_isNullable = isNullable;
		}
	}

	override {
		size_t length() @property {
			return _values.length;
		}

		string name() @property {
			return _name;
		}

		bool isNullable() @property {
			return _isNullable;
		}

		bool isWriteable() @property {
			return true;
		}

		static immutable OUT_OF_BOUNDS = `Data field value index out of bounds!!!`;
		bool isNull(size_t index)
		{
			enforce(index < _nullFlags.length, OUT_OF_BOUNDS);
			return isNullable? _nullFlags[index]: false;
		}

		string getStr(size_t index)
		{
			import std.conv: to;
			enforce(index < _values.length, OUT_OF_BOUNDS);
			return isNull(index)? null: _values[index].to!string;
		}

		string getStr(size_t index, string defaultValue)
		{
			import std.conv: to;
			enforce(index < _values.length, OUT_OF_BOUNDS);
			return isNull(index)? defaultValue: _values[index].to!string;
		}

		import webtank.datctrl.common;
		mixin GetStdJSONFieldFormatImpl;
		mixin GetStdJSONFieldValueImpl;

		ValueType get(size_t index) {
			return _values[index];
		}

		ValueType get(size_t index, ValueType defaultValue)
		{
			enforce(index < _values.length, OUT_OF_BOUNDS);
			return isNull(index)? defaultValue: _values[index];
		}

		static if( isEnumFormat!(FormatType) )
		{
			FormatType enumFormat() {
				return _enumFormat;
			}
		}

		void set(ValueType value, size_t index)
		{
			enforce(index < _nullFlags.length, OUT_OF_BOUNDS);
			enforce(index < _values.length, OUT_OF_BOUNDS);
			_nullFlags[index] = false;
			_values[index] = value;
		}

		void nullify(size_t index)
		{
			enforce(index < _nullFlags.length, OUT_OF_BOUNDS);
			enforce(index < _values.length, OUT_OF_BOUNDS);
			_nullFlags[index] = true;
			_values[index] = ValueType.init;
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
			_values.insertInPlace(index, ValueType.init.repeat(count));
			_nullFlags.insertInPlace(index, true.repeat(count));
		}

		void addItems(ValueType[] values, size_t index = size_t.max)
		{
			import std.array: insertInPlace;
			import std.range: repeat;
			if( index == size_t.max ) {
				index = _values.length? _values.length - 1: 0;
			}
			_values.insertInPlace(index, values);
			_nullFlags.insertInPlace(index, false.repeat(values.length));
		}

		import std.json: JSONValue, JSON_TYPE;
		void fromStdJSONValue(JSONValue jValue, size_t index)
		{
			enforce(index < _nullFlags.length, OUT_OF_BOUNDS);
			enforce(index < _values.length, OUT_OF_BOUNDS);
			
			import webtank.common.std_json.from: fromStdJSON;
			if( jValue.type == JSON_TYPE.NULL ) {
				_nullFlags[index] = true;
				_values[index] = ValueType.init;
			} else {
				_nullFlags[index] = false;
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