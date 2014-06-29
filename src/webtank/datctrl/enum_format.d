module webtank.datctrl.enum_format;

import std.traits, std.range;
import std.typecons;


/++
$(LOCALE_EN_US Struct represents format for enumerated type of field)
$(LOCALE_RU_RU Структура представляет формат для перечислимого типа поля)
+/
struct EnumFormat(alias enumValues, string nullString = null)
	if( isArray!( typeof(enumValues) ) )
{
	alias ArgElemType = ElementType!( typeof(enumValues) );
	
	enum bool hasNames = isTuple!( ArgElemType );
	enum bool isStatic = true;
	
	static if( hasNames )
	{
		static assert( ArgElemType.length == 2, 
			"Static enum value tuple must contain 2 elements. Use plain array if value-only enum needed." );
			
		alias ValueType = typeof(ArgElemType[0]);
		
		static string getName(ValueType value)
		{
			foreach( ref pair; enumValues )
			{
				if( pair[0] == value )
					return pair[1];
			}
			assert( 0, "Attempt to get name for value that doesn't exist in EnumFormat object!!" );
		}
		
		template getName(ValueType value)
		{
			enum string getName = .getName(value);
		}
		
		static ValueType getValue(string name)
		{
			foreach( ref pair; enumValues )
			{
				if( pair[1] == name )
					return pair[0];
			}
			assert( 0, "Attempt to get value for name that doesn't exist in EnumFormat object!!" );
		}
		
		template getValue(string name)
		{
			enum string getValue = .getValue(name);
		}
		
		static string[] names() @property
		{
			string[] result;
			result.length = enumValues.length;
			
			foreach( i, ref pair; enumValues )
				result[i] = pair[1];
			
			return result;
		}
		
		///Оператор для обхода значений перечислимого типа через foreach
		///Первый параметр - имя (строка), второй - значение
		static int opApply(int delegate(string name, ValueType value) dg)
		{	foreach( ref pair; enumValues )
			{	auto result = dg(pair[1], pair[0]);
				if(result)
					return result;
			}
			return 0;
		}
	
		///Оператор для обхода значений перечислимого типа через foreach
		///в случае одного параметра (значения)
		static int opApply(int delegate(ValueType value) dg)
		{	foreach( ref pair; enumValues )
			{	auto result = dg(pair[0]);
				if(result)
					return result;
			}
			return 0;
		}
	}
	else 
	{
		alias ValueType = ArgElemType;
		
		///Оператор для обхода значений перечислимого типа через foreach
		///в случае одного параметра (значения)
		static int opApply(int delegate(ValueType value) dg)
		{	foreach( ref value; enumValues )
			{	auto result = dg(value);
				if(result)
					return result;
			}
			return 0;
		}
		
	}
	
	static ValueType[] values() @property
	{
		ValueType[] result;
		result.length = enumValues.length;
		
		foreach( i, ref val; enumValues )
		{	
			static if( hasNames )
				result[i] = val[0]; //Первый элемент кортежа - значение
			else
				result[i] = val;
		}
		
		return result;
	}

}

struct EnumFormat( T, bool hasNames )
	if( !isArray!(T) )
{
	alias ValueType = T;
	enum bool isStatic = false;
	
	//Имя для пустого (отсутствующего) значения null
	string nullString;
	
	static if( hasNames )
	{
		//Массив пар "значение: название" для перечислимого типа
		Tuple!(ValueType, string)[] _pairs;

		this( Tuple!(ValueType, string)[] pairs )
		{
			_pairs = pairs;
		
		}
		
		this( Tuple!(ValueType, string)[] pairs, string nullStr )
		{
			_pairs = pairs;
			nullString = nullStr;
		
		}
		
		string getName(ValueType value) const
		{
			foreach( ref pair; _pairs )
			{
				if( pair[0] == value )
					return pair[1];
			}
			assert( 0, "Attempt to get name for value that doesn't exist in EnumFormat object!!" );
		}
		
		ValueType getValue(string name) const
		{
			foreach( ref pair; _pairs )
			{
				if( pair[1] == name )
					return pair[0];
			}
			assert( 0, "Attempt to get value for name that doesn't exist in EnumFormat object!!" );
		}
		
		///Возвращает набор имен для перечислимого типа
		string[] names() @property const
		{	
			string[] result;
			result.length = _pairs.length;
			
			foreach( i, ref pair; _pairs )
				result[i] = pair[1];
			
			return result;
		}
		
		///Возвращает набор значений перечислимого типа
		ValueType[] values() @property const
		{	
			ValueType[] result;
			result.length = _pairs.length;
			
			foreach( i, ref pair; _pairs )
				result[i] = pair[0];
			
			return result;
		}
		
		///Оператор для обхода значений перечислимого типа через foreach
		///Первый параметр - имя (строка), второй - значение
		int opApply(int delegate(string name, ValueType value) dg) const
		{	foreach( ref pair; _pairs )
			{	auto result = dg(pair[1], pair[0]);
				if(result)
					return result;
			}
			return 0;
		}
	
		///Оператор для обхода значений перечислимого типа через foreach
		///в случае одного параметра (значения)
		int opApply(int delegate(ValueType value) dg)
		{	foreach( ref pair; _pairs )
			{	auto result = dg(pair[0]);
				if(result)
					return result;
			}
			return 0;
		}
	}
	else
	{
		//Массив значений перечислимого типа
		private ValueType[] _values;
		
		this( ValueType[] values, string nullString )
		{
			_values = values;
			_nullString = nullString;
		}
		
		///Возвращает набор значений перечислимого типа
		ValueType[] values() @property const
		{	
			return _values.dup;
		}
		
		///Оператор для обхода значений перечислимого типа через foreach
		///в случае одного параметра (значения)
		int opApply(int delegate(ValueType value) dg)
		{	foreach( ref value; _values )
			{	auto result = dg(value);
				if(result)
					return result;
			}
			return 0;
		}
	}
}

enum isEnumFormat(E) = isInstanceOf!(EnumFormat, E);

