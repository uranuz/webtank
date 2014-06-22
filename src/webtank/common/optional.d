module webtank.common.optional;

import std.conv;

///Returns true if T is nullable type
template isNullable(T)
{	enum bool isNullable = __traits( compiles, { bool aaa = T.init is null; } );
}

///Шаблон, возвращает true, если N является Nullable или NullableRef
template isStdNullable(N)
{	import std.typecons;
	static if( is( N == NullableRef!(TL1), TL1... ) )
		enum bool isStdNullable = true;
	else static if( is( N == Nullable!(TL2), TL2... ) )
		enum bool isStdNullable = true;
	else
		enum bool isStdNullable = false;
}

///Шаблон возвращает базовый тип для Nullable или NullableRef
template getStdNullableType(N)
{	import std.typecons, std.traits;
	static if( is( N == NullableRef!(TL2), TL2... ) )
		alias TL2[0] getStdNullableType;
	else static if( is( N == Nullable!(TL2), TL2... ) )
		alias TL2[0] getStdNullableType;
	else
		static assert (0, `Type ` ~ fullyQualifiedName!(N) ~ ` can't be used as Nullable type!!!` );
}


///Возвращает true, если тип N произведён от шаблона Optional
template isOptional(O)
{	enum bool isOptional = is( O == Optional!(T), T ) ;
}

template OptionalValueType(O)
{	import std.traits;
	static if( is( O == Optional!(T), T ) )
		alias T OptionalValueType;
	else
		static assert (0, `Type ` ~ fullyQualifiedName!(O) ~ ` is not an instance of Optional!!!` );
}

unittest
{	
	interface Vasya {}
	
	class Petya {}
	
	struct Vova {}
	
	alias void function(int) FuncType;
	alias bool delegate(string, int) DelType;
	
	//Check that these types are nullable
	assert( isNullable!Vasya );
	assert( isNullable!Petya );
	assert( isNullable!(string) );
	assert( isNullable!(int*) );
	assert( isNullable!(string[string]) );
	assert( isNullable!(FuncType) );
	assert( isNullable!(DelType) );
	assert( isNullable!(dchar[7]*) );
	
	//Check that these types are not nullable
	assert( !isNullable!Vova );
	assert( !isNullable!(double) );
	assert( !isNullable!(int[8]) );
	assert( !isNullable!(double) );
}

// unittest
// {
// 	Nullable!int a = null;
// 	Nullable!int b = 5;
// 	int c = 5;
// 	assert(a != b);
// 	assert(b == c);
// 	assert(a == null);
// 	assert(b != null);
// 	assert(b + 1 == 6);
// 	struct S
// 	{
// 		public bool opEquals(S) const /+pure @safe nothrow+/
// 		{ return true; }
// 		public bool opEquals(int) const /+pure @safe nothrow+/
// 		{ return true; }
// 	}
// 	Nullable!S s;
// 	assert(s != 0);
// 	assert(s.opCmp(null) == 0);
// 	assert(a.opCmp(null) == 0);
// 	assert(b.opCmp(null) > 0);
// 	assert(b.opCmp(6) < 0);
// 	assert(b.opCmp(5) == 0);
// }




Optional!(T) optional(T)(auto ref inout(T) value) 
	/+pure @safe nothrow+/
{	Optional!(T) result = value;
	return result;
}

///Шаблон для представления типов, имеющих выделенное пустое,
///или неинициализированное состояние
struct Optional(T)
	if( isNullable!T )
{
	private T _value;

/**
Constructor binding $(D this) with $(D value).
 */
	this(A)( auto ref T value) 
		inout /+pure @safe nothrow+/
	{	_value = value; }

/**
Returns $(D true) if and only if $(D this) is in the null state.
 */
	@property bool isNull() 
		const /+pure @safe nothrow+/
	{	return _value is null;
	}
	
	/**
Forces $(D this) to the null state.
 */
	void nullify()
		/+pure @safe nothrow+/
	{	_value = null;
	}
    
	bool opEquals(RHS)(auto ref RHS rhs)
		const /+pure @safe nothrow+/
		if ( !isOptional!(RHS) )
	{	return _value == rhs; }

	bool opEquals(RHS)(auto ref RHS rhs)
		const /+pure @safe nothrow+/
		if( isOptional!(RHS) )
	{	return _value == rhs._value; }

/**
Assigns $(D value) to the internally-held state.
 */
	auto ref opAssign(ref T rhs) 
		/+pure @safe nothrow+/
	{	return _value = rhs; }

/**
Gets the value. $(D this) must not be in the null state.
This function is also called for the implicit conversion to $(D T).
 */
	@property ref inout(T) value() 
		inout /+pure @safe nothrow+/
	{	return _value;
	}

	auto ref inout(T) get()(auto ref inout(T) defaultValue) 
		inout /+pure @safe nothrow+/
	{	return isNull ? defaultValue : _value ;
	}
	
// 	string toString() 
// 		inout /+pure @safe nothrow+/
// 	{	return _value; }

/**
Implicitly converts to $(D T).
$(D this) must not be in the null state.
 */
	alias value this;
}

struct Optional(T)
	if( !isNullable!T )
{
	private T _value;
	private bool _isNull = true;

/**
Constructor initializing $(D this) with $(D value).
 */
	this( A )( auto ref inout(A) value )
		inout /+pure @safe nothrow+/
	{	_value = value;
		_isNull = false;
	}
	
	this( A : typeof(null) )( A value ) 
		inout /+pure @safe nothrow+/
	{	_isNull = true;
	}

/**
Returns $(D true) if and only if $(D this) is in the null state.
 */
	@property bool isNull() 
		const /+pure @safe nothrow+/
	{	return _isNull;
	}

/**
Forces $(D this) to the null state.
 */
	void nullify()()
		/+pure @safe nothrow+/
	{
		.destroy(_value);
		_isNull = true;
	}
	
	int opCmp(RHS)(auto ref inout(RHS) rhs)
		const /+pure @safe nothrow+/
		if( !isOptional!(RHS) )
	{	int r;
		if( !isNull )
		{
			static if( __traits(compiles, _value.opCmp(rhs)) )
			{ r = _value.opCmp(rhs._value); }
			else
			{ r = _value < rhs ? -1 : (_value > rhs ? 1 : 0); }
		}
		else { r = -1; }
		return r;
	}

	int opCmp(RHS)(auto ref inout(RHS) rhs)
		const /+pure @safe nothrow+/
		if( isOptional!(RHS) )
	{	int r;
		if ( !isNull && !rhs.isNull)
		{ r = 0; }
		else if( !isNull && rhs.isNull )
		{ r = 1; }
		else if ( isNull && !rhs.isNull )
		{ r = -1; }
		else { r = this == rhs._value; }
		return r;
	}

	int opCmp( RHS : typeof(null) )( RHS rhs )
		const /+pure @safe nothrow+/
	{ return !isNull ? 1 : 0; }
	
	bool opEquals( RHS )( auto ref RHS rhs )
		const /+pure @safe nothrow+/
		if( !isOptional!(RHS) )
	{	return !isNull && _value == rhs; }

	bool opEquals( RHS )( auto ref RHS rhs )
		const /+pure @safe nothrow+/
		if( isOptional!(RHS) )
	{	return _isNull == rhs._isNull &&
			_value == rhs._value;
	}

	bool opEquals( RHS : typeof(null) )( RHS value )
		const /+pure @safe nothrow+/
	{ return isNull; }

/**
Gets the value. $(D this) must not be in the null state.
This function is also called for the implicit conversion to $(D T).
 */
	@property ref inout(T) value() 
		inout /+pure @safe nothrow+/
	{	enum message = "Attemt to get value of null " ~ typeof(this).stringof ~ "!!!";
		assert(!isNull, message);
		return _value;
	}
    
	auto ref inout(T) get()(auto ref inout(T) defaultValue) 
		inout /+pure @safe nothrow+/
	{	return ( isNull ? defaultValue : _value );
	}

/**
Assigns $(D value) to the internally-held state. If the assignment
succeeds, $(D this) becomes non-null.
 */
	auto ref opAssign( RHS )( auto ref RHS value )
		/+pure @safe nothrow+/
	{	this._value = value;
		this._isNull = false;
		return value;
	}

	auto ref opAssign( RHS : typeof(null) )( RHS value )
		/+pure @safe nothrow+/
	{	this._value = T.init;
		this._isNull = true;
		return value;
	}
	
// 	string toString() 
// 		inout /+pure @safe nothrow+/
// 	{	return ( isNull ? "null" : _value.to!string ); }

/**
Implicitly converts to $(D T).
$(D this) must not be in the null state.
 */
    alias value this;
}

import std.stdio, std.datetime;

// void main() 
// {
// 
// 	Optional!Date a;
// 	
// 	writeln("test");
// 	
// 	a = null;
// 	
// 	writeln(a.isNull);
// 	
// 	
// }
