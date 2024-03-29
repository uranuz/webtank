module webtank.common.optional;

import std.traits: isDynamicArray, isAssociativeArray;
import trifle.traits: isNullableType, isUnsafelyNullable;

class OptionalException: Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
		@safe pure nothrow 
	{
		super(msg, file, line);
	}
}

///Возвращает true, если тип N произведён от шаблона Optional
template isOptional(O)
{
	import std.traits: Unqual;
	enum bool isOptional = is( Unqual!O == Optional!Rest, Rest... );
}

template isUndefable(O)
{
	import std.traits: Unqual;
	static if( is( Unqual!O == Optional!(T, Rest), T, Rest... ) )
		enum bool isUndefable = Rest[0];
	else
		enum bool isUndefable = false;
}

template OptionalValueType(O)
{
	import std.traits: fullyQualifiedName;
	static if( is( O == Optional!(T, Rest), T, Rest... ) )
		alias OptionalValueType = T;
	else
		static assert(false, `Type ` ~ fullyQualifiedName!(O) ~ ` is not an instance of Optional!!!` );
}

unittest {
	assert(!isOptional!int);
	assert(!isOptional!string);
	assert(isOptional!(Optional!int));
	assert(isOptional!(Optional!(int*)));
	assert(isOptional!(Optional!string));
	assert(isOptional!(Optional!Exception));
	
	assert(isOptional!(Undefable!int));
	assert(isOptional!(Undefable!(int*)));
	assert(isOptional!(Undefable!string));
	assert(isOptional!(Undefable!Exception));

	assert(isUndefable!(Undefable!int));
	assert(isUndefable!(Undefable!(int*)));
	assert(isUndefable!(Undefable!string));
	assert(isUndefable!(Undefable!Exception));
}

Optional!(T) optional(T)(auto ref inout(T) value) 
	/+pure @safe nothrow+/
{
	return Optional!(T)(value);
}

private enum OptState: ubyte {
	Undef,
	Null,
	Set
}

///Шаблон для представления типов, имеющих выделенное пустое,
///или неинициализированное состояние
struct Optional(T, bool isUndefOpt = false)
{
	import std.conv: to;

	private T _value;
	static if( !isUnsafelyNullable!T || isUndefOpt ) {
		private OptState _state = isUndefOpt? OptState.Undef: OptState.Null;
	}

/**
Constructor binding $(D this) with $(D value).
 */
	this(RHS)(auto ref RHS rhs)
		pure @safe nothrow
		if( !is(RHS == typeof(null)) && !is(RHS == void[]) )
	{
		_assign(rhs);
	}
	
	this(RHS: typeof(null))(RHS rhs)
		pure @safe nothrow
	{
		_assign(rhs);
	}

	static if( isDynamicArray!T || isAssociativeArray!T )
	{
		this(RHS)(RHS rhs)
			pure @safe nothrow
			if( is( RHS == void[]) )
		{
			_assign(T.init);
		}
	}

	private void _assign(RHS: typeof(null))(RHS)
		pure @safe nothrow
	{
		_value = typeof(_value).init;
		static if( !isUnsafelyNullable!T || isUndefOpt ) {
			_state = OptState.Null;
		}
	}

	private void _assign(RHS)(auto ref RHS rhs)
		pure @safe nothrow
		if( !isOptional!RHS && !is(RHS == typeof(null)) )
	{
		_value = rhs;
		static if( isUnsafelyNullable!RHS && isUndefOpt ) {
			_state = rhs is null? OptState.Null: OptState.Set;
		} else static if( !isUnsafelyNullable!RHS ) {
			_state = OptState.Set;
		}
	}

	private void _assign(RHS)(auto ref RHS rhs)
		if( isOptional!RHS )
	{
		alias rhsT = OptionalValueType!(RHS);

		if( rhs.isSet ) {
			_value = rhs._value;
		} else {
			static if( isNullableType!rhsT ) {
				_value = null; // Explicitly set as null to solve problems with arrays
			} else {
				_value = typeof(_value).init;
			}
		}

		static if( !isUnsafelyNullable!T || isUndefOpt )
		{
			static if( !isUnsafelyNullable!rhsT || isUndefable!RHS ) {
				_state = rhs._state;
			} else {
				_state = rhs.isSet? OptState.Set: OptState.Null;
			}
		}
	}

/**
Returns $(D true) if and only if $(D this) is in the null state.
 */
	bool isNull() @property
		inout pure @safe nothrow
	{
		static if( isUnsafelyNullable!T && !isUndefOpt ) {
			return _value is null;
		} else static if( isUnsafelyNullable!T ) {
			return _state == OptState.Null || (_value is null && _state != OptState.Undef);
		} else {
			return _state == OptState.Null;
		}
	}

	static if( isUndefOpt ) {
		bool isUndef() @property
			inout pure @safe nothrow
		{
			return _state == OptState.Undef;
		}
	}

	bool isSet() @property
		inout pure @safe nothrow
	{
		static if( isUnsafelyNullable!T && !isUndefOpt ) {
			return _value !is null;
		} else static if( isUnsafelyNullable!T ) {
			return _state == OptState.Set && _value !is null;
		} else {
			return _state == OptState.Set;
		}
	}

	bool opEquals(RHS)(auto ref const(RHS) rhs)
		inout pure @safe nothrow
	{
		static if( is( RHS == typeof(null) ) ) {
			return isNull;
		} else static if( isOptional!RHS ) {
			static if( isUndefOpt ) {
				if( isNull && rhs.isNull || isUndef && rhs.isUndef )
					return true;
			} else {
				if( isNull && rhs.isNull )
					return true;
			}

			return isSet && rhs.isSet && _value == rhs._value;
		} else static if( isUnsafelyNullable!RHS ) {
			return _value == rhs;
		} else {
			return isSet && _value == rhs;
		}
	}

/+
	int opCmp(RHS)(auto ref inout(RHS) rhs)
		const // pure @safe nothrow
		if( isOptional!RHS )
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
		const // pure @safe nothrow
		if( isOptional!RHS )
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
		const // pure @safe nothrow
	{ return !isNull ? 1 : 0; }
+/

/**
Assigns $(D value) to the internally-held state.
 */
	void opAssign(RHS)(auto ref RHS rhs) 
		pure @safe nothrow
		if( !is(RHS == typeof(null)) && !is(RHS == void[]) )
	{
		_assign(rhs);
	}

	void opAssign(RHS: typeof(null))(RHS rhs) 
		pure @safe nothrow
	{
		_assign(null);
	}

	static if( isDynamicArray!T || isAssociativeArray!T )
	{
		void opAssign(RHS)(RHS rhs) 
			pure @safe nothrow
			if( is(RHS == void[]) )
		{
			_assign(T.init);
		}
	}

	// Postplit is added in order to get rid of error:
	// .opAssign is not callable because it is annotated with @disable
	this(this) inout pure @safe nothrow {}

/**
Gets the value. $(D this) must not be in the null state.
This function is also called for the implicit conversion to $(D T).
 */
	ref inout(T) value() @property
		inout pure /+@safe nothrow+/
	{
		import std.traits: isDynamicArray, isAssociativeArray;
		import std.exception: enforce;
		static if( !isDynamicArray!T && !isAssociativeArray!T )
		{
			// For dynamic array or associative array it's is safe to work with null, so allow getting null value,
			// because it should be practical in most cases.
			// But for classes, pointers, function pointers or delegates it is not.
			// So help to not shoot into someone's foot as early as possible
			enum message = "Attempt to get value of " ~ typeof(this).stringof ~ " that is not initialized!!! ";
			enforce!OptionalException(isSet, message);
		}
		return _value;
	}

	auto ref inout(T) get()(auto ref inout(T) defaultValue) 
		inout pure @safe nothrow
	{	return isSet? _value: defaultValue;
	}

	auto ref T getOrSet()(auto ref T defaultValue) 
		pure @safe nothrow
	{	
		if( !isSet ) {
			this = defaultValue;
		}
		return _value;
	}
	
	string toString()
		const pure @safe
	{
		return isSet? _value.to!string: (isNull? "Optional.Null": "Optional.Undef");
	}
	
	alias value this;
}

alias Undefable(T) = Optional!(T, true);

unittest
{
	// Checks for value optional without Undef state
	Optional!int a;
	Optional!int b = 5;
	int c = 5;
	assert(a != b);
	assert(b == c);
	assert(a == null);
	assert(a.isNull);
	assert(!a.isSet);
	assert(b != null);
	assert(b.isSet);
	assert(!b.isNull);
	assert(b + 1 == 6);
}

unittest
{
	// Some tests for arrays
	Optional!(int[]) a;

	assert(a.isNull);
	assert(a == null);
	assert(!a.isSet);

	Optional!(int[]) b = [];

	assert(!b.isNull);
	assert(b != null);
	assert(b is null); // Because array is implicitly extracted from optional

	Optional!(int[]) c;
	c = [];
	assert(!c.isNull);
	assert(c.isSet);
	assert(c != null);
	assert(c is null);

	Optional!(int[]) d = null;
	assert(d is null);
	assert(d.isNull);
	assert(!d.isSet);

	Optional!(int[]) f;
	f = null;
	assert(f.isNull);
	assert(!f.isSet);
	assert(f == null);
	assert(f is null);

	Optional!(int[]) e;
	e = f;
	assert(e.isNull);
	assert(!e.isSet);
	assert(e == null);
	assert(e is null);
}

unittest
{
	// Some tests for arrays with Undefable
	Undefable!(int[]) a;

	assert(a.isUndef);
	assert(!a.isNull);
	assert(!a.isSet);
	assert(a != null);
	assert(a is null); // Because array is implicitly extracted from optional

	Undefable!(int[]) b = [];

	assert(!b.isUndef);
	assert(!b.isNull);
	assert(b != null);
	assert(b is null); // Because array is implicitly extracted from optional
	assert(b.isSet);

	Undefable!(int[]) c = null;

	assert(!c.isUndef);
	assert(c.isNull);
	assert(!c.isSet);
	assert(c == null);
	assert(c is null); // Because array is implicitly extracted from optional

	Undefable!(int[]) d;
	d = [];
	assert(!d.isUndef);
	assert(!d.isNull);
	assert(d.isSet);
	assert(d != null);
	assert(d is null);

	Undefable!(int[]) f;
	f = null;
	assert(!f.isUndef);
	assert(f.isNull);
	assert(!f.isSet);
	assert(f == null);
	assert(f is null);
}

unittest
{
	// Checks for reference optional without Undef state
	// Built-in arrays and AAs are special case, because they are safe when null
	import std.exception: assertThrown;
	Optional!string a;
	assert(a.isNull);
	assert(!a.isSet);
	assert(a is null); // It is safe for built-in arrays to work with null
	assert(a.value is null);
	a = "SuperTest";
	assert(!a.isNull);
	assert(a.isSet);
	assert(a.value == "SuperTest");

	// Working with other types such as classes, pointers and function pointers is not safe when they are null
	class Test { int b; }
	Optional!Test t;
	assert(t.isNull);
	assert(!t.isSet);

	// Getting and working null class could result into segfault so not allow it
	assertThrown!OptionalException(t is null);
	assert(t == null); // This is overloaded operator and can be used safe'ly
	Test ttt;
	assertThrown!OptionalException(ttt = t);
	assertThrown!OptionalException(ttt = t.value);
	ttt = t.get(null); // Instead this must work to explicitly get null class reference
}

unittest
{
	// Checks for value Undefable
	import std.exception: assertThrown;
	Undefable!int a;
	assert(a.isUndef);
	assert(!a.isNull);
	assert(!a.isSet);
	assert(a != null);
	int aaa;
	assertThrown!OptionalException(aaa = a);
	assertThrown!OptionalException(aaa = a.value);

	Undefable!int b = 10;
	assert(!b.isUndef);
	assert(!b.isNull);
	assert(b.isSet);
	assert(b != null);
	assert(b == 10);
	assert(b != a);
	int bbb = b;
	assert(bbb == 10);
	bbb = 30;
	bbb = b.value;
	assert(bbb == 10);

	Undefable!int c;
	c = null;
	assert(!c.isUndef);
	assert(c.isNull);
	assert(!c.isSet);
	assert(c == null);
	assert(c != a);
	assert(c != b);
	assert(c != 100500);
	int ccc;
	assertThrown!OptionalException(ccc = a);
	assertThrown!OptionalException(ccc = a.value);
}

unittest
{
	// Checks for reference Undefable
	import std.exception: assertThrown;
	Undefable!string a;
	assert(a.isUndef);
	assert(!a.isNull);
	assert(!a.isSet);
	assert(a is null);
	assert(a.value is null);

	class Test { int b; }
	Undefable!Test t;
	assert(t.isUndef);
	assert(!t.isNull);
	assert(!t.isSet);
	assertThrown!OptionalException(t is null);
	assert(t != null); // This is not null, cause it's undef, right?
	Test ttt;
	assertThrown!OptionalException(ttt = t);
	assertThrown!OptionalException(ttt = t.value);

	Undefable!Test ko;
	ko = null;
	assert(!ko.isUndef);
	assert(ko.isNull);
	assert(!ko.isSet);
	assertThrown!OptionalException(ko is null);
	assert(ko == null); // Now it is null
	Test kokoko;
	assertThrown!OptionalException(kokoko = ko);
	assertThrown!OptionalException(kokoko = ko.value);
}

unittest
{
	Undefable!string ko1 = "aaa";
	Undefable!string ko2;
	ko2 = ko1;
	assert(ko2 == "aaa");
	assert(ko2 != null);
	assert(!ko2.isUndef);
	assert(!ko2.isNull);
	assert(ko2.isSet);

	Undefable!string ko3 = ko1;
	assert(ko3 == "aaa");
	assert(!ko3.isUndef);
	assert(!ko3.isNull);
	assert(ko3.isSet);
	assert(ko2 == ko3);

	Undefable!(size_t[]) ko4 = cast(size_t[]) [5,4,3,2];
	assert(!ko4.isUndef);
	assert(!ko4.isNull);
	assert(ko4.isSet);
	
	Undefable!(size_t[]) ko5;
	ko5 = ko4;
	assert(!ko5.isUndef);
	assert(!ko5.isNull);
	assert(ko5.isSet);
	assert(ko5 == ko5);
}

unittest {
	import std.datetime: Date;
	Optional!Date dt;
	assert(dt.isNull);
	assert(!dt.isSet);
}

unittest {
	// Test special case with 0 int value
	Undefable!size_t nollInt = 0;
	assert(!nollInt.isNull);
	assert(!nollInt.isUndef);
	assert(nollInt.isSet);

	Undefable!size_t nollInt2;
	assert(!nollInt2.isNull);
	assert(nollInt2.isUndef);
	assert(!nollInt2.isSet);
	nollInt2 = 0;
	assert(!nollInt2.isNull);
	assert(!nollInt2.isUndef);
	assert(nollInt2.isSet);
}