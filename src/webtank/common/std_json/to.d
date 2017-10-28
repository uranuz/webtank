module webtank.common.std_json.to;

import std.json, std.traits, std.conv, std.typecons;

import webtank.common.optional;
import webtank.common.optional_date;
import webtank.common.std_json.exception;

/++
$(LOCALE_EN_US
	Function serializes D language value into std.json.JSONValue struct
)

$(LOCALE_RU_RU
	Функция сериализует значение языка D в структуру типа std.json.JSONValue
)
+/
JSONValue toStdJSON(T)(T dValue)
{
	import std.datetime: Date, DateTime, TimeOfDay, SysTime;
	static if( is(T == JSONValue) ) {
		return dValue;
	}
	else
	{
		static if( isBoolean!T ) {
			return JSONValue(dValue);
		}
		else static if( isIntegral!T )
		{
			static if( isSigned!T ) {
				return JSONValue(dValue.to!long);
			} else static if( isUnsigned!T ) {
				return JSONValue(dValue.to!ulong);
			} else {
				static assert(false, "This should never happen!!!"); //Это не должно произойти))
			}
		} else static if( isFloatingPoint!T ) {
			return JSONValue(dValue.to!real);
		}
		else static if( isSomeString!T )
		{
			if( dValue is null ) {
				return JSONValue(null);
			} else {
				return JSONValue(dValue.to!string);
			}
		}
		else static if( isArray!T )
		{
			if( dValue is null ) {
				return JSONValue(null);
			}
			else
			{
				JSONValue[] jArray;
				jArray.length = dValue.length;

				foreach( i, elem; dValue ) {
					jArray[i] = toStdJSON(elem);
				}

				return JSONValue(jArray);
			}
		}
		else static if( isAssociativeArray!T )
		{
			static if( isSomeString!(KeyType!T) )
			{
				if( dValue is null ) {
					return JSONValue(null);
				}
				else
				{
					JSONValue[string] jArray;
					foreach( key, val; dValue )
					{
						// Не будем выводить свойства которые имеют тип Undefable с состоянием isUndef
						static if( isOptional!(ValueType!T) && OptionalIsUndefable!(ValueType!T) )
						{
							if( !val.isUndef ) {
								jArray[key.to!string] = toStdJSON(val);
							}
						} else {
							jArray[key.to!string] = toStdJSON(val);
						}
					}
					return JSONValue(jArray);
				}
			} else {
				static assert(false, "Only string types are allowed for object keys!!!");
			}
		}
		else static if( isTuple!T )
		{
			JSONValue[] jArray;
			jArray.length = dValue.length;

			foreach( i, elem; dValue ) {
				jArray[i] = toStdJSON(elem);
			}

			return JSONValue(jArray);
		} else static if( isOptional!T ) {
			return dValue.isSet? toStdJSON(dValue.value): JSONValue(null);
		} else static if( is( T == OptionalDate ) ) {
			return JSONValue([
				"day": toStdJSON(dValue.day),
				"month": toStdJSON(dValue.month),
				"year": toStdJSON(dValue.year)
			]);
		}
		else static if( is(T == Date) || is(T == DateTime) || is(T == TimeOfDay) || is(T == SysTime) ) {
			// Строковый формат для дат и времени более компактен и привычен, поэтому выводим в нём вместо объекта JSON
			return JSONValue(dValue.toISOExtString());
		} else static if(
			is(T == struct)
			&& __traits(hasMember, T, "toStdJSON") // Проверка, что это собственный метод структуры
			&& __traits(compiles, { auto test = dValue.toStdJSON(); })
		) {
			return dValue.toStdJSON();
		}
		else static if( is(T == struct) )
		{
			JSONValue[string] jArray;
			foreach( name; __traits(allMembers, T) )
			{
				static if( __traits(compiles, {
					auto test = __traits(getMember, dValue, name);
				})) {
					alias FieldType = typeof(__traits(getMember, dValue, name));
					// Не будем выводить свойства которые имеют тип Undefable с состоянием isUndef
					static if( isOptional!FieldType && OptionalIsUndefable!FieldType )
					{
						if( !__traits(getMember, dValue, name).isUndef ) {
							jArray[name] = toStdJSON( __traits(getMember, dValue, name) );
						}
					} else {
						jArray[name] = toStdJSON( __traits(getMember, dValue, name) );
					}
				}
			}
			return JSONValue(jArray);
		}
		else static if(
			(is(T == class) || is(T == interface))
			&& __traits(hasMember, T, "toStdJSON") // Проверка, что это собственный метод класса
			&& __traits(compiles, { auto test = dValue.toStdJSON(); })
		) {
			if( dValue is null ) {
				return JSONValue();
			} else {
				return dValue.toStdJSON();
			}
		} else {
			static assert(false, "This value's type is not of one implemented JSON type!!!" );
		}
	}
}