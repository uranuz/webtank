module webtank.datctrl.memory_data_field;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.enum_format;

class MemoryDataField(alias FormatType): IWriteableDataField!(FormatType)
{
	alias ValueType = DataFieldValueType!(FormatType);

protected:
	ValueType[] _values;
	bool[] _nullFlags;
	string _name;
	bool _isNullable;
	
	static if( isEnumFormat!(FormatType) )
	{
		this( 
			ValueType[] values,
			bool[] nullFlags,
			string fieldName, bool isNullable,
			FormatType enumFormat
		)
		{	_values = values;
			_nullFlags = nullFlags;
			_name = fieldName;
			_isNullable = isNullable;
			_enumFormat = enumFormat;
		}
		
		FormatType _enumFormat;
	}
	
	this( 
		ValueType[] values,
		bool[] nullFlags,
		string fieldName, bool isNullable
	)
	{	_values = values;
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
		
		JSONValue getStdJSONFormat()
		{
		
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
	} //override

}