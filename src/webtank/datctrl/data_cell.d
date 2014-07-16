module webtank.datctrl.data_cell;

import std.conv;

import webtank.datctrl.data_field, webtank.datctrl.enum_format;


interface IBaseDataCell
{
	bool isNullable() @property;
	
	bool isWriteable() @property;
	
	bool isNull() @property;
	
	string getStr();
	
	string getStr(string defaultValue);

}

interface IBaseWriteableDataCell: IBaseDataCell
{
	void nullify();
	
	void setNullable(bool value) @property;

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
	
	static if( isEnumFormat!(FormatType) )
	{
		FormatType _enumFormat;
	}

public:

	this() {}
	
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
			return isNull ? null : _value.to!string;
		}
		
		string getStr(string defaultValue) @property
		{
			return isNull ? defaultValue : _value.to!string;
		}
		
		
		ValueType get()
		{
			return _value;
		}
		
		ValueType get(ValueType defaultValue)
		{
			return isNull ? defaultValue : _value;
		}
		
		static if( isEnumFormat!(FormatType) )
		{
			FormatType enumFormat()  @property
			{
				return _enumFormat;
			}
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
		
		void setNullable(bool value) @property
		{
			_isNullable = value;
		}
	}

}

// void main()
// {
// 	import std.stdio;
// 	
// 	auto cell = new WriteableDataCell!(int)(10);
// 
// 	writeln( cell.get() );
// }