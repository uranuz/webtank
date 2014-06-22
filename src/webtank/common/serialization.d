module webtank.common.serialization;
 
import std.json, std.traits, std.conv, std.typecons;

import webtank.common.optional;

interface IStdJSONSerializeable
{	JSONValue getStdJSON();
// 	IStdJSONSerializeable fromStdJSON(JSONValue jValue);
}

//Класс исключения сериализации
class SerializationException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

/++
$(LOCALE_EN_US
	Function serializes D language value into std.json.JSONValue struct
)

$(LOCALE_RU_RU
	Функция сериализует значение языка D в структуру типа std.json.JSONValue
)
+/
JSONValue getStdJSON(T)(T dValue)
{	/+pragma(msg, T);+/
	static if( is( T == JSONValue ) )
		return dValue;
	else
	{	JSONValue jValue;
		static if( isBoolean!T )
		{	jValue = dValue;
		}
		else static if( isIntegral!T )
		{	static if( isSigned!T )
			{	jValue = dValue.to!long;
			}
			else static if( isUnsigned!T )
			{	jValue = dValue.to!ulong;
			}
			else
				static assert( 0, "This should never happen!!!" ); //Это не должно произойти))
		}
		else static if( isFloatingPoint!T )
		{	jValue = dValue.to!real;
		}
		else static if( isSomeString!T )
		{	
			if( dValue is null )
				jValue = null;
			else
				jValue = dValue.to!string;
		}
		else static if( isArray!T )
		{	
			if( dValue is null )
				jValue = null;
			else
			{
				JSONValue[] jArray;
				jArray.length = dValue.length;
				
				foreach( i, elem; dValue )
					jArray[i] = getStdJSON( elem );
					
				jValue = jArray;
			}
		}
		else static if( isAssociativeArray!T )
		{	static if( isSomeString!( KeyType!(T) ) )
			{	
				if( dValue is null )
					jValue = null;
				else
				{
					JSONValue[string] jArray;
					
					foreach( key, val; dValue )
						jArray[key.to!string] = getStdJSON( val );
						
					jValue = jArray;
				}
			}
			else
				static assert( 0, "Only string types are allowed for object keys!!!" );
		}
		else static if( isTuple!T )
		{	
			JSONValue[] jArray;
			jArray.length = dValue.length;
			
			foreach( i, elem; dValue )
				jArray[i] = getStdJSON( elem );
				
			jValue = jArray;
		}
		else static if( isOptional!T )
		{	alias OptionalValueType!T BaseT;
			if( dValue.isNull )
				jValue = null;
			else
				jValue = getStdJSON( dValue.value );
		}
		else static if( is( T: IStdJSONSerializeable ) )
		{	
			if( dValue is null ) 
				jValue = null;
			else
				jValue = dValue.getStdJSON();
		}
		else static if( is( T: std.datetime.Date ) )
		{	
			jValue = dValue.toISOExtString();
		}
		else
			static assert( 0, "This value's type is not of one implemented JSON type!!!" );
		return jValue;
	}
}

/++
$(LOCALE_EN_US
	Function deserializes std.json.JSONValue struct into D language value 
)

$(LOCALE_RU_RU
	Функция десериализует структуру std.json.JSONValue в значение языка D
)
+/
T getDLangValue(T, uint recursionLevel = 1)(JSONValue jValue)
{	pragma(msg, T, "  ",recursionLevel);
	static if( is( T == JSONValue ) )
	{	return jValue; //Raw JSONValue
	}
	else static if( isBoolean!T )
	{	if( jValue.type == JSON_TYPE.TRUE )
			return true;
		else if( jValue.type == JSON_TYPE.FALSE )
			return false;
		else
			throw new SerializationException("JSON value doesn't match boolean type!!!");
	}
	else static if( isIntegral!T )
	{	if( jValue.type == JSON_TYPE.UINTEGER )
			return jValue.uinteger.to!T;
		else if( jValue.type == JSON_TYPE.INTEGER )
			return jValue.integer.to!T;
		else
			throw new SerializationException("JSON value doesn't match unsigned integer type!!!");
	}
	else static if( isFloatingPoint!T )
	{	if( jValue.type == JSON_TYPE.FLOAT )
			return jValue.floating.to!T;
		else if( jValue.type == JSON_TYPE.INTEGER )
			return jValue.integer.to!T;
		else if( jValue.type == JSON_TYPE.UINTEGER  )
			return jValue.uinteger.to!T;
		else
			throw new SerializationException("JSON value doesn't match floating point type!!!");
	}
	else static if( isSomeString!T )
	{	if( jValue.type == JSON_TYPE.STRING )
			return jValue.str.to!T;
		else if( jValue.type == JSON_TYPE.NULL )
		{	return null;
		}
		else
			throw new SerializationException("JSON value doesn't match string type!!!");
	}
	else static if( isAssociativeArray!T )
	{	
// 		static assert( recursionLevel, "Recursion level limit!!!" );
		alias  KeyType!T AAKeyType;
		static assert( isSomeString!AAKeyType, "JSON object's key must be of string type!!!" );
		alias ValueType!T AAValueType;
		if( jValue.type == JSON_TYPE.OBJECT )
		{	T result;
			foreach( key, val; jValue.object )
				result[key.to!AAKeyType] = getDLangValue!( AAValueType, recursionLevel-1 )(val);
			return result;
		}
		else if( jValue.type == JSON_TYPE.NULL )
		{	return null;
		}
		else
			throw new SerializationException("JSON value doesn't match object type!!!");
	}
	else static if( isArray!T )
	{	import std.range;
// 		static assert( recursionLevel, "Recursion level limit!!!" );
		alias ElementType!T AElementType;
		
		if( jValue.type == JSON_TYPE.ARRAY )
		{	T array;
			foreach( i, val; jValue.array )
				array ~= getDLangValue!( AElementType, recursionLevel-1 )(val);
			return array;
		}
		else if( jValue.type == JSON_TYPE.NULL )
		{	return null;
		}
		else
			throw new SerializationException("JSON value doesn't match array type!!!");
	}
	else static if( isTuple!T )
	{	if( jValue.type == JSON_TYPE.ARRAY )
		{	T result;
			if( jValue.array.length != T.length )
				throw new SerializationException("JSON array length " ~ T.length.to!string ~ " expected but " ~ jValue.array.length.to!string ~ " found!!!");
			foreach( i, ref element; result )
				element = getDLangValue!( typeof(element), recursionLevel-1 )(jValue.array[i]);
			return result;
		}
		else if( jValue.type == JSON_TYPE.NULL )
		{	return Tuple!();
		}
		else
			throw new SerializationException("JSON value doesn't match tuple type!!!");
	}
	else static if( isOptional!T )
	{	alias OptionalValueType!T BaseT;
		pragma(msg, "OptionalValueType!T ", BaseT)
		T result;
		if( jValue.type != JSON_TYPE.NULL )
			result = getDLangValue!(BaseT)(jValue);
		return result;
	}
	
// 	else static if( is( T: IStdJSONSerializeable ) )
// 	{	return ( cast(T) dValue.fromStdJSON(jValue) );
// 	}
	else
		static assert( 0, "This should never happen!!!" );
}
