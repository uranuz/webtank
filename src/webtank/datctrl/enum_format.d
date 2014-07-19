module webtank.datctrl.enum_format;

import std.traits, std.range, std.json;
import std.typecons;

import webtank.common.conv;

/++
$(LOCALE_EN_US Struct represents format for enumerated type of field)
$(LOCALE_RU_RU Структура представляет формат для перечислимого типа поля)
+/
struct EnumFormat( T, bool hasNames )
{
	alias ValueType = T;

	//Имя для пустого (отсутствующего) значения null
	string nullString;

	static if( hasNames )
	{
		//Массив пар "значение: название" для перечислимого типа
		private Tuple!(ValueType, string)[] _pairs;

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
		
		this( ValueType[] values )
		{
			_values = values;
		}
		
		this( ValueType[] values, string nullStr )
		{
			_values = values;
			nullString = nullStr;
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
	
	/++
	$(LOCALE_EN_US Serializes enumerated field format into std.json)
	$(LOCALE_RU_RU Сериализует формат перечислимого типа в std.json)
	+/
	JSONValue getStdJSON() const
	{	
		JSONValue[string] jArray; //Массив полей для формата перечислимого типа
		
		//Словарь перечислимых значений (числовой ключ --> строковое имя)
		JSONValue[string] jEnumNames;
		
		//Массив, определяющий порядок перечислимых значений
		JSONValue[] jEnumKeys;
		
		static if( hasNames )
		{
			jEnumKeys.length = _pairs.length;
			
			foreach( i, pair; _pairs )
			{
				jEnumNames[ pair[0].conv!string ] = pair[1];
				jEnumKeys[i] = pair[0].conv!string;
			}
		}
		else
		{
			jEnumKeys.length = _values.length;
			
			foreach( i, val; _values )
			{
				jEnumNames[ val.conv!string ] = val.conv!string;
				jEnumKeys[i] = val.conv!string;
			}
		}
		
		jArray["enum_n"] = jEnumNames;
		jArray["enum_k"] = jEnumKeys;
		
		return JSONValue(jArray);
	}
}

enum isEnumFormat(E) = isInstanceOf!(EnumFormat, E);

