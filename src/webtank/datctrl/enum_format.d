module webtank.datctrl.enum_format;

import std.traits, std.range, std.json;
import std.typecons;
import std.algorithm: canFind;

import webtank.common.conv;

/++
$(LOCALE_EN_US Struct represents format for enumerated type of field)
$(LOCALE_RU_RU Структура представляет формат для перечислимого типа поля)
+/
struct EnumFormat( T, bool withNames )
{
	alias ValueType = T;
	alias hasNames = withNames;

	static if( hasNames )
	{
		//Массив пар "значение: название" для перечислимого типа
		private Tuple!(ValueType, string)[] _pairs;

		this( Tuple!(ValueType, string)[] pairs )
		{
			_pairs = pairs;
		
		}
		
		string getName(ValueType value) const
		{
			foreach( ref pair; _pairs )
			{
				if( pair[0] == value )
					return pair[1];
			}
			assert( 0, "Attempt to get name for value *" ~ value.conv!string ~ "* that doesn't exist in EnumFormat object!!" ~ _pairs.conv!string );
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
		
		bool hasName(string name) const
		{
			return _pairs.canFind!"a[1] == b"(name);
		}
		
		bool hasValue(ValueType value) const
		{
			return _pairs.canFind!"a[0] == b"(value);
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
		
		this( ValueType[] values )
		{
			_values = values;
		}
		
		bool hasValue(ValueType value) const
		{
			import std.algorithm: canFind;
			
			return _pairs.canFind(name);
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
	
	string getStr(ValueType value) const
	{
		static if( hasNames )
		{
			return getName( value );
		}
		else
		{
			static if( isSomeString!(ValueType) )
			{
				import std.algorithm : canFind;
				assert( _values.canFind(value), "Value is not present in enum format!" );
				return value.conv!string;
			}
			else static if( is( ValueType == enum ) )
			{
				alias BaseType = OriginalType!(ValueType);
				static if( isSomeString!(BaseType) )
				{
					import std.algorithm : canFind;
					assert( _values.canFind(value), "Value is not present in enum format!" );
					return value.conv!string;
				}
				else
				{
					//Вывод идентификатора значения перечислимого типа из кода на D
					return value.stringof;
				}
			}
			else
			{
				import std.algorithm : canFind;
				assert( _values.canFind(value), "Value is not present in enum format!" );
				return value.conv!string;
			}
		}
	}
	
	string opIndex(ValueType value) const
	{
		return getStr(value);
	}
	
	///Оператор in для проверки наличия ключа в наборе значений перечислимого типа
	bool opBinaryRight(string op)(ValueType value) inout 
		if( op == "in" )
	{	return hasValue(value); }
	
	/++
	$(LOCALE_EN_US Serializes enumerated field format into std.json)
	$(LOCALE_RU_RU Сериализует формат перечислимого типа в std.json)
	+/
	JSONValue toStdJSON() const
	{

		//Массив элементов перечислимого типа
		JSONValue[] jEnumItems;
		
		static if( hasNames )
		{
			jEnumItems.length = _pairs.length;
			JSONValue[string] jEnumItem;
			
			foreach( i, pair; _pairs )
			{
				jEnumItems[i] = [ 
					"v": JSONValue( pair[0].conv!string ), 
					"n": JSONValue( pair[1] ) 
				];
			}
		}
		else
		{
			jEnumItems.length = _values.length;
			
			foreach( i, val; _values )
			{
				jEnumItems[i] = [ 
					"v": JSONValue( val.conv!string ), 
				];
			}
		}

		return JSONValue(jEnumItems);
	}
}

import std.range: ElementType;
import std.typecons: isTuple;

enum isEnumFormat(E) = isInstanceOf!(EnumFormat, E);

auto enumFormat(Pair)(Pair[] pairs)
	if( isTuple!(Pair) && Pair.length == 2 )
{
	return EnumFormat!( typeof(pairs[0][0]), true )(pairs);
}

auto enumFormat(T)(T[] values)
	if( !isTuple!(T) )
{
	return EnumFormat!( T, false )(values);

}

