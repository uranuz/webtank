module webtank.common.std_json.from;

import std.json: JSONValue, JSONType;

/++
$(LANG_EN
	Function deserializes std.json.JSONValue struct into D language value 
)
$(LANG_RU
	Функция десериализует структуру std.json.JSONValue в значение языка D
)
+/
T fromStdJSON(T)(JSONValue jValue)
{
	import std.conv: text, to;
	import std.traits;
	import std.typecons: Tuple, isTuple;
	import webtank.common.optional: Optional, isOptional, OptionalValueType;
	import std.datetime: Date, DateTime, TimeOfDay, SysTime;
	import webtank.common.std_json.exception;
	import webtank.common.conv: isStdDateOrTime;

	static if( is( Unqual!T == JSONValue ) ) {
		return jValue; //Raw JSONValue given
	}
	else static if( isBoolean!T )
	{
		if( jValue.type == JSONType.true_ ) {
			return true;
		} else if( jValue.type == JSONType.false_ ) {
			return false;
		} else {
			throw new SerializationException("JSON value doesn't match boolean type!!!");
		}
	}
	else static if( isIntegral!T )
	{
		if( jValue.type == JSONType.uinteger ) {
			return jValue.uinteger.to!T;
		} else if( jValue.type == JSONType.integer ) {
			return jValue.integer.to!T;
		} else {
			throw new SerializationException("JSON value doesn't match unsigned integer type!!!");
		}
	}
	else static if( isFloatingPoint!T )
	{
		if( jValue.type == JSONType.float_ ) {
			return jValue.floating.to!T;
		} else if( jValue.type == JSONType.integer ) {
			return jValue.integer.to!T;
		} else if( jValue.type == JSONType.uinteger ) {
			return jValue.uinteger.to!T;
		} else {
			throw new SerializationException("JSON value doesn't match floating point type!!!");
		}
	}
	else static if( isSomeString!T )
	{
		if( jValue.type == JSONType.string ) {
			return jValue.str.to!T;
		} else if( jValue.type == JSONType.null_ ) {
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
		if( jValue.type == JSONType.object )
		{
			T result;
			foreach( key, val; jValue.object ) {
				result[key.to!AAKeyType] = fromStdJSON!(AAValueType)(val);
			}
			return result;
		} else if( jValue.type == JSONType.null_ ) {
			return null;
		} else {
			throw new SerializationException("JSON value doesn't match object type!!!");
		}
	}
	else static if( isArray!T )
	{
		import std.range;
		alias ElementType!T AElementType;
		
		if( jValue.type == JSONType.array )
		{
			T array;
			foreach( i, val; jValue.array ) {
				array ~= fromStdJSON!(AElementType)(val);
			}
			return array;
		} else if( jValue.type == JSONType.null_ ) {
			return null;
		} else {
			throw new SerializationException("JSON value doesn't match array type!!!");
		}
	}
	else static if( isTuple!T )
	{
		static if( T.length > 0 )
		{
			if( jValue.type == JSONType.array )
			{
				if( jValue.array.length != T.length ) {
					throw new SerializationException("JSON array length " ~ T.length.to!string ~ " expected but " 
						~ jValue.array.length.to!string ~ " found!!!");
				}

				T result;
				foreach( i, ref element; result ) {
					element = fromStdJSON!(typeof(element))(jValue.array[i]);
				}
				return result;
			}
			else if( jValue.type == JSONType.object )
			{
				import std.exception: enforce;
				enforce!SerializationException(
					T.fieldNames.length == T.Types.length,
					`Imposible to deserialize tuple from object when not all of its items are named`
				);
				T result;
				foreach( i, name; T.fieldNames)
				{
					if( auto valPtr = name in jValue.object ) {
						result[i] = fromStdJSON!(T.Types[i])(*valPtr);
					}
				}
				return result;
			}
			else {
				throw new SerializationException("JSON value doesn't match tuple type!!!");
			}
		}
		else
		{
			if( jValue.type == JSONType.null_ || (jValue.type == JSONType.array && jValue.array.length == 0) ) {
				return Tuple!();
			} else {
				throw new SerializationException("Expected JSON null or array of zero length!!!");
			}
		}
	}
	else static if( isOptional!T )
	{
		alias BaseT = OptionalValueType!T;
		T result;
		if( jValue.type == JSONType.null_ ) {
			result = null; // We need to set null explicitly, because of Undefable
		} else {
			result = fromStdJSON!(BaseT)(jValue);
		}
		return result;
	}
	else static if( is( T == struct ) )
	{
		static if( __traits(hasMember, T, "fromStdJSON") ) {
			return T.fromStdJSON(jValue);
		} else {
			T result;
			if( jValue.type == JSONType.object )
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
			} else if( jValue.type == JSONType.string ) {
				static if( isStdDateOrTime!T ) {
					// Явно говорим, что из строки будем получать дату или время в формате ISO
					result = T.fromISOExtString(jValue.str);
				} else {
					// Пока для других типов преобразование из строки не доступно. Может позже... Но это не точно...
					throw new SerializationException("Deserialization from string to struct is only possible for date and time for now...");
				}
			} else if( jValue.type != JSONType.null_ ) {
				throw new SerializationException("Expected JSON object or null to deserialize into structure of type: " ~ T.stringof ~ ", but got: " ~ jValue.type.text);
			}
			return result;
		}
	}
	else static if(
		is( T == class)
		&& __traits(hasMember, T, "fromStdJSON")
	) {
		return T.fromStdJSON(jValue);
	}
	else
		static assert( 0, "This should never happen!!!" );
}
