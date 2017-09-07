module webtank.datctrl.memory_data_field;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.enum_format;

class MemoryDataField(alias FormatType): IWriteableDataField!(FormatType)
{
	alias ValueType = DataFieldValueType!(FormatType);

protected:
	string _name;
	ValueType[] _values;
	bool[] _nullFlags;
	bool _isNullable;
	
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
	}
	
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

	override
	{
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
		
		bool isNull(size_t index) {
			return isNullable ? ( _nullFlags[index] ) : false;
		}
	
		string getStr(size_t index) {
			return isNull? null : _values[index].to!string;
		}
		
		string getStr(size_t index, string defaultValue) {
			return isNull ? defaultValue : _values[index].to!string;
		}

		import std.json: JSONValue;
		JSONValue getStdJSONFormat()
		{
			assert(false, "Not implemented yet!");
		}
		
		ValueType get(size_t index) {
			return _values[index];
		}
		
		ValueType get(size_t index, ValueType defaultValue) {
			return isNull ? defaultValue : _values[index];
		}

		static if( isEnumFormat!(FormatType) )
		{
			FormatType enumFormat() {
				return _enumFormat;
			}
		}
		
		void set(ValueType value, size_t index)
		{
			_nullFlags[index] = false;
			_values[index] = value;
		}
		
		void nullify(size_t index)
		{
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
			_values.insertInPlace(index, ValueType.init.repeat(count));
		}

		void addItems(ValueType[] values, size_t index = size_t.max)
		{
			import std.array: insertInPlace;
			_values.insertInPlace(index, values);
		}
	} //override

}

IBaseWriteableDataField[] makeMemoryDataFields(RecordFormatT)(RecordFormatT format)
{
	IBaseWriteableDataField[] dataFields;
	foreach( fieldName; RecordFormatT.tupleOfNames!() )
	{
		alias FieldFormatDecl = RecordFormatT.getFieldFormatDecl!(fieldName);
		alias DataFieldType = MemoryDataField!(FieldFormatDecl);
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
}