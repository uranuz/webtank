module webtank.db.postgresql.serialize;

///Функция преобразования параметров в строковое представление для PostgreSQL
string toPGString(T)(T value)
{
	import std.traits: isNumeric, isSomeString, isArray;
	import std.datetime: DateTime, SysTime, Date, TimeOfDay;
	import std.uuid: UUID;
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
	else static if( is(T == bool) || isNumeric!(T) || is(T == UUID) )
	{
		return value.to!string;
	}
	else static if( isSomeString!(T) )
	{
		return value is null? null: value.to!string;
	}
	else static if( is(T == SysTime) || is(T == DateTime) || is(T == Date) || is(T == TimeOfDay) )
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


string getPGTypeName(QualType)()
{
	import std.traits: Unqual, isSomeString, isArray;
	import std.range: ElementType;
	import webtank.common.optional: isOptional, OptionalValueType;
	import webtank.db.postgresql.consts: PGTypeName;
	import datetime: TimeOfDay, SysTime, DateTime, Date;
	import std.uuid: UUID;
	import std.json: JSONValue;

	alias T = Unqual!QualType;

	static if( is(T == bool) ) {
		return PGTypeName.boolean;
	} else static if( is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) ) {
		return PGTypeName.smallint;
	} else static if( is(T == int) || is(T == uint) ) {
		return PGTypeName.integer;
	} else static if( is(T == long) || is(T == ulong) ) {
		return PGTypeName.bigint;
	} else static if( is(T == float) ) {
		return PGTypeName.float_;
	} else static if( is(T == double) ) {
		return PGTypeName.double_;
	} else static if( isSomeString!T ) {
		return PGTypeName.text;
	} else static if( is(T == SysTime) || is(T == DateTime) ) {
		return PGTypeName.timestamp;
	} else static if( is(T == TimeOfDay) ) {
		return PGTypeName.time;
	} else static if( is(T == Date) ) {
		return PGTypeName.date;
	} else static if( is(T == UUID) ) {
		return PGTypeName.uuid;
	} else static if( is(T == JSONValue) ) {
		return PGTypeName.jsonb;
	} else static if( isOptional!T ) {
		return getPGType!(OptionalValueType!T)();
	} else static if( isArray!T ) {
		return getPGType!(ElementType!T) ~ `[]`;
	} else static assert(false, `Cannot determine PostgreSQL type name for this type`);
}