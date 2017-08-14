module webtank.common.std_json.to;

import std.json, std.traits, std.conv, std.typecons;

import webtank.common.optional;
import std.datetime: Date;
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
	static if( is( T == JSONValue ) ) {
		return dValue;
	}
	else
	{
		JSONValue jValue;
		static if( isBoolean!T ) {
			jValue = dValue;
		}
		else static if( isIntegral!T )
		{
			static if( isSigned!T ) {
				jValue = dValue.to!long;
			} else static if( isUnsigned!T ) {
				jValue = dValue.to!ulong;
			} else {
				static assert( 0, "This should never happen!!!" ); //Это не должно произойти))
			}
		} else static if( isFloatingPoint!T ) {
			jValue = dValue.to!real;
		}
		else static if( isSomeString!T )
		{
			if( dValue is null ) {
				jValue = null;
			} else {
				jValue = dValue.to!string;
			}
		}
		else static if( isArray!T )
		{
			if( dValue is null ) {
				jValue = null;
			}
			else
			{
				JSONValue[] jArray;
				jArray.length = dValue.length;

				foreach( i, elem; dValue ) {
					jArray[i] = toStdJSON(elem);
				}

				jValue = jArray;
			}
		}
		else static if( isAssociativeArray!T )
		{
			static if( isSomeString!(KeyType!T) )
			{
				if( dValue is null ) {
					jValue = null;
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
					jValue = jArray;
				}
			} else {
				static assert( 0, "Only string types are allowed for object keys!!!" );
			}
		}
		else static if( isTuple!T )
		{
			JSONValue[] jArray;
			jArray.length = dValue.length;

			foreach( i, elem; dValue ) {
				jArray[i] = toStdJSON(elem);
			}

			jValue = jArray;
		}
		else static if( isOptional!T )
		{
			alias BaseT = OptionalValueType!T;
			if( dValue.isSet ) {
				jValue = toStdJSON(dValue.value);
			} else {
				jValue = null;
			}
		} else static if( is( T: std.datetime.Date ) ) {
			jValue = dValue.toISOExtString();
		}
		else static if ( is( T == struct ) )
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
			jValue = jArray;
		}
		else static if ( is( T == class ) && __traits(compiles, {
			auto result = dValue.toStdJSON();
		}) ) {
			if( dValue is null ) {
				return JSONValue();
			} else {
				return dValue.toStdJSON();
			}
		}
		else {
			static assert( 0, "This value's type is not of one implemented JSON type!!!" );
		}
		return jValue;
	}
}