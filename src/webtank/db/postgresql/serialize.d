module webtank.db.postgresql.serialize;

///Функция преобразования параметров в строковое представление для PostgreSQL
string toPGString(T)(T value)
{
	import std.traits: isNumeric, isSomeString, isArray;
	import std.datetime: DateTime, SysTime, Date;
	import std.conv: to;
	import std.range: ElementType;
	import std.array: replace;
	import std.json: JSONValue;
	import webtank.common.optional: isOptional;

	static if( is(T == typeof(null)) )
	{
		return null;
	}
	else static if( isOptional!T )
	{
		return value.isSet? toPGString(value.value): null;
	}
	else static if( is(T == bool) || isNumeric!(T) )
	{
		return value.to!string;
	}
	else static if( isSomeString!(T) )
	{
		return value is null? null: value.to!string;
	}
	else static if( is(T == SysTime) || is(T == DateTime) || is(T == Date) )
	{
		return value.toISOExtString();
	}
	else static if( isArray!(T) )
	{
		alias ElemType = ElementType!T;
		if( value is null ) {
			return null;
		}

		string arrayData;
		foreach( i, elem; value )
		{
			if( arrayData.length > 0 ) {
				arrayData ~= ", ";
			}
			string item = toPGString(elem);
			if( item is null ) {
				arrayData ~= `null`;
				continue;
			}
			static if( isSomeString!(ElemType) ) {
				item = `"` ~ item.replace(`"`, `\"`) ~ `"`;
			}
			arrayData ~= item;
		}
		return "{" ~ arrayData ~ "}";
	}
	else static if( is( T: JSONValue ) )
	{
		return value.toString();
	}
	else static assert(false, `Unexpected type of parameter to safely represent in PostgreSQL query`);
}
