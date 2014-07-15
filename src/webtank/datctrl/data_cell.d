module webtank.datctrl.data_cell;


interface IBaseDataCell
{
	bool isNullable() @property;
	
	bool isWriteable() @property;
	
	bool isNull() @property;
	
	string getStr() @property;
	
	string getStr(string defaultValue) @property;

}

interface IBaseWriteableDataCell
{


}

interface IDataCell(FormatT): IBaseDataCell
{
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType);
	
	ValueType get();
	
	ValueType get(ValueType defaultValue);
	
	static if( isEnumFormat!(FormatType) )
	{
		FormatType enumFormat()  @property;
	}

}

interface IWriteableDataCell(FormatT): IDataCell!(FormatT), IBaseWriteableDataCell
{
	
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType);
	
	void set(ValueType value);
	
	void nullify();
	
	void isNullable(bool value) @property;

}

class WriteableDataCell(FormatT): IWriteableDataCell!(FormatT)
{
public:
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType);

protected:
	ValueType _value;
	bool _isNull = true;
	bool _isNullable = true;

public:

	this( ValueType value )
	{
		_value = value;
		_isNull = false;
	}
	
	override 
	{
		bool isNullable() @property
		{
			return _isNullable;
		}
		
		bool isWriteable() @property
		{
			return true;
		}
		
		bool isNull() @property
		{
			return _isNullable ? _isNull : false;
		}
		
		string getStr() @property
		{
			return _isNull : null : _value.to!string;
		}
		
		string getStr(string defaultValue) @property
		{
			return _isNull ? defaultValue : _value.to!string;
		}
		
		
		void set(ValueType value)
		{
			_value = value;
			_isNull = false;
		}
	
		void nullify()
		{
			if( _isNullable )
			{
				_isNull = true;
				_value = ValueType.init;
			}
		}
		
		void isNullable(bool value) @property
		{
			_isNullable = value;
		}
	}

}

