module webtank.common.std_json.from;

import std.json, std.traits, std.conv, std.typecons;

import webtank.common.optional;
import std.datetime: Date;
import webtank.common.std_json.exception;

/++
$(LOCALE_EN_US
	Function deserializes std.json.JSONValue struct into D language value 
)

$(LOCALE_RU_RU
	Функция десериализует структуру std.json.JSONValue в значение языка D
)
+/
T fromStdJSON(T, uint recursionLevel = 1)(JSONValue jValue)
{
	static if( is( T == JSONValue ) ) {
		return jValue; //Raw JSONValue given
	}
	else static if( isBoolean!T )
	{
		if( jValue.type == JSON_TYPE.TRUE ) {
			return true;
		} else if( jValue.type == JSON_TYPE.FALSE ) {
			return false;
		} else {
			throw new SerializationException("JSON value doesn't match boolean type!!!");
		}
	}
	else static if( isIntegral!T )
	{
		if( jValue.type == JSON_TYPE.UINTEGER ) {
			return jValue.uinteger.to!T;
		} else if( jValue.type == JSON_TYPE.INTEGER ) {
			return jValue.integer.to!T;
		} else {
			throw new SerializationException("JSON value doesn't match unsigned integer type!!!");
		}
	}
	else static if( isFloatingPoint!T )
	{
		if( jValue.type == JSON_TYPE.FLOAT ) {
			return jValue.floating.to!T;
		} else if( jValue.type == JSON_TYPE.INTEGER ) {
			return jValue.integer.to!T;
		} else if( jValue.type == JSON_TYPE.UINTEGER ) {
			return jValue.uinteger.to!T;
		} else {
			throw new SerializationException("JSON value doesn't match floating point type!!!");
		}
	}
	else static if( isSomeString!T )
	{
		if( jValue.type == JSON_TYPE.STRING ) {
			return jValue.str.to!T;
		} else if( jValue.type == JSON_TYPE.NULL ) {
			return null;
		} else {
			throw new SerializationException("JSON value doesn't match string type!!!");
		}
	}
	else static if( isAssociativeArray!T )
	{
		alias  KeyType!T AAKeyType;
		static assert( isSomeString!AAKeyType, "JSON object's key must be of string type!!!" );
		alias ValueType!T AAValueType;
		if( jValue.type == JSON_TYPE.OBJECT )
		{
			T result;
			foreach( key, val; jValue.object ) {
				result[key.to!AAKeyType] = fromStdJSON!( AAValueType, recursionLevel-1 )(val);
			}
			return result;
		} else if( jValue.type == JSON_TYPE.NULL ) {
			return null;
		} else {
			throw new SerializationException("JSON value doesn't match object type!!!");
		}
	}
	else static if( isArray!T )
	{
		import std.range;
		alias ElementType!T AElementType;
		
		if( jValue.type == JSON_TYPE.ARRAY )
		{
			T array;
			foreach( i, val; jValue.array ) {
				array ~= fromStdJSON!( AElementType, recursionLevel-1 )(val);
			}
			return array;
		} else if( jValue.type == JSON_TYPE.NULL ) {
			return null;
		} else {
			throw new SerializationException("JSON value doesn't match array type!!!");
		}
	}
	else static if( isTuple!T )
	{
		static if( T.length > 0 )
		{
			if( jValue.type == JSON_TYPE.ARRAY )
			{
				if( jValue.array.length != T.length ) {
					throw new SerializationException("JSON array length " ~ T.length.to!string ~ " expected but " 
						~ jValue.array.length.to!string ~ " found!!!");
				}

				T result;
				foreach( i, ref element; result ) {
					element = fromStdJSON!( typeof(element), recursionLevel-1 )(jValue.array[i]);
				}
				return result;
			} else {
				throw new SerializationException("JSON value doesn't match tuple type!!!");
			}
		}
		else
		{
			if( jValue.type == JSON_TYPE.NULL || (jValue.type == JSON_TYPE.ARRAY && jValue.array.length == 0) ) {
				return Tuple!();
			} else {
				throw new SerializationException("Expected JSON null or array of zero length!!!");
			}
		}
	}
	else static if( isOptional!T )
	{
		alias OptionalValueType!T BaseT;
		T result;
		if( jValue.type != JSON_TYPE.NULL ) {
			result = fromStdJSON!(BaseT)(jValue);
		}
		return result;
	}
	else static if( is( T == struct ) )
	{
		static if( __traits(compiles, {
			auto result = T.fromStdJSON(jValue);
		}) ) {
			return T.fromStdJSON(jValue);
		} else {
			T result;
			if( jValue.type == JSON_TYPE.OBJECT )
			{
				foreach( name; __traits(allMembers, T) )
				{
					if( auto valuePtr = name in jValue )
					{
						static if(__traits(compiles, {
							__traits(getMember, result, name) = typeof(__traits(getMember, result, name)).init;
						})) {
							__traits(getMember, result, name) = fromStdJSON!(
								typeof(__traits(getMember, result, name))
							)(*valuePtr);
						}
					}
				}
			} else if( jValue.type != JSON_TYPE.NULL ) {
				throw new SerializationException("Expected JSON object or null to deserialize into structure of type: " ~ T.stringof);
			}
			return result;
		}
	}
	else static if( is( T == class) && __traits(compiles, {
		auto result = T.fromStdJSON(jValue);
	}) ) {
		return T.fromStdJSON(jValue);
	}
	else
		static assert( 0, "This should never happen!!!" );
}