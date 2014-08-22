module webtank.common.optional;

import std.conv;

class OptionalException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) 
		@safe pure nothrow 
	{
		super(msg, file, line);
	}
}

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
		alias OptionalValueType = T;
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
	this(A)( auto ref T val) 
		inout /+pure @safe nothrow+/
	{	_value = val; }

/**
Returns $(D true) if and only if $(D this) is in the null state.
 */
	@property bool isNull() 
		const /+pure @safe nothrow+/
	{	return _value is null;
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
	alias values this;
}

struct Optional(T)
	if( !isNullable!T )
{
	private T _value;
	private bool _isNull = true;

/**
Constructor initializing $(D this) with $(D value).
 */
	this( A )( auto ref inout(A) val )
		inout /+pure @safe nothrow+/
	{	_value = val;
		_isNull = false;
	}
	
	this( A : typeof(null) )( A val ) 
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
	@property ref inout(T) value(int line = __LINE__) 
		inout /+pure @safe nothrow+/
	{	enum message = "Attemt to get value of null " ~ typeof(this).stringof ~ "!!! ";
		assert(!isNull, message ~ line.to!string);
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
	auto ref opAssign( RHS )( auto ref RHS rhs )
		if( !is( RHS == typeof(null) ) )
		/+pure @safe nothrow+/
	{	
		static if( isOptional!(RHS) )
		{
			if( rhs.isNull )
				_isNull = true;
			else
			{
				_value = rhs.value;
				_isNull = false;
			}
		}
		else
		{
			_value = rhs;
			_isNull = false;
		}
		
		return rhs;
	}

	auto ref opAssign( RHS )( RHS rhs )
		if( is( RHS == typeof(null) ) )
		/+pure @safe nothrow+/
	{	_value = T.init;
		_isNull = true;
		return rhs;
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


import std.exception, std.datetime, std.typetuple;

struct OptionalDate
{
protected:
	Optional!short _year;
	Optional!ubyte _month;
	Optional!ubyte _day;
	
public:
	this( Date date )
	{
		_year = date.year;
		_month = date.month;
		_day = date.day;
	}
	
	alias YearTypeList = TypeTuple!( short, int, Optional!short, Optional!int, typeof(null) );
	alias MonthOrDayTypeList = TypeTuple!( ubyte, int, Optional!ubyte, Optional!int, typeof(null) );
	
	this(Y, M, D)( Y initYear, M initMmonth, D initDay  )
	{
		enum bool isYearPred(Type) = is( Y == Type );
		enum bool isMonthPred(Type) = is( M == Type );
		enum bool isDayPred(Type) = is( D == Type );
		
		static if( 
			anySatisfy!( isYearPred, YearTypeList ) &&
			anySatisfy!( isMonthPred, MonthOrDayTypeList ) &&
			anySatisfy!( isDayPred, MonthOrDayTypeList )
		)
		{
			this.year = initYear;
			this.month = initMmonth;
			this.day = initDay;
		}
		else
			static assert(0, `Unsupported ctor argument types for OptionalDate`);
	}
	
	Optional!short year() @property
		const
	{	return _year;
	}
	
	void year(Optional!short value) @property
	{	_year = value;
	}
	
	void year(Optional!int value) @property
	{
		if( value.isNull )
			_year = null;
		else
			_year = cast(short) value.value;
	}
	
	void year(int value) @property
	{	_year = cast(short) value;
	}
	
	Optional!ubyte month() @property
	{	return _month;
	}
	
	void month(Optional!ubyte value) @property
	{	_month = value;
	}
	
	void month(Optional!int value) @property
	{
		if( value.isNull )
			_month = null;
		else
			_month = cast(ubyte) value.value;
	}
	
	void month(int value) @property
	{	_month = cast(ubyte) value;
	}
	
	Optional!ubyte day() @property
		const
	{	return _day;
	}
	
	void day(Optional!ubyte value) @property
	{	_day = value;
	}
	
	void day(Optional!int value) @property
	{
		if( value.isNull )
			_day = null;
		else
			_day = cast(ubyte) value.value;
	}
	
	void day(int value) @property
	{	_day = cast(ubyte) value;
	}
	
	bool isDefined() @property
	{
		return !_year.isNull && !_month.isNull && !_day.isNull;
	}
	
	bool isNull() @property
	{
		return _year.isNull && _month.isNull && _day.isNull;
	}
	
	Date get() 
	{
		enforceEx!OptionalException( isDefined, "Attempt to get not fully defined date value of OptionalDate!!!" );
		return Date(_year, _month, _day);
	}
	
	auto ref opAssign( RHS : Date )(auto ref RHS value)
	{
		this = OptionalDate(value);
	}
	
	auto ref opAssign( RHS : OptionalDate )(auto ref RHS value)
	{	this._year = value._year;
		this._month = value._month;
		this._day = value._day;
	}
	
	auto ref opAssign( RHS : typeof(null) )( RHS value )
		/+pure @safe nothrow+/
	{	_year = null;
		_month = null;
		_day = null;
		return this;
	}	
}