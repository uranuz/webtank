module webtank.common.conv;

import std.traits: Unqual;

enum bool isStdDateOrTime(T) =
	is(Unqual!T == Date)
	|| is(Unqual!T == DateTime)
	|| is(Unqual!T == TimeOfDay)
	|| is(Unqual!T == SysTime);

// Набор костылей для std.conv для преобразования типов данных так как нужно "нам"
// Основная проблема функции, что этой реализации, что она не работает рекурсивно
T conv(T, V)(V value)
{
	import std.conv: to, parse;
	import std.algorithm: canFind;
	import std.traits: isSomeString, OriginalType, isDynamicArray, isArray;
	import std.algorithm: startsWith;
	import webtank.common.optional: Optional, isUnsafelyNullable, isOptional;
	static if( is(T == enum) )
	{
		static if( isSomeString!( OriginalType!(T) ) && isSomeString!(V) )
		{
			auto enumValues = [ EnumMembers!T ];
			auto tmp = to!(OriginalType!(T))(value);

			if( !enumValues.canFind(tmp) ) {
				throw new ConvException( `Value "` ~ value.to!string ~ `" is not enum value of type "` ~ ValueType.stringof ~ `"!!!` );
			}

			return cast(T) tmp;
		} else {
			return cast(T) value.to!( OriginalType!(T) );
		}
	} else static if( is(V == enum) && isSomeString!( OriginalType!(V) ) && isSomeString!(T) ) {
		return (cast(OriginalType!(V)) value).to!T;
	} else static if( isStdDateOrTime!T ) {
		return fromPGTimestamp!T(value);
	} else static if( is(T: bool) && isSomeString!V ) {
		return value.toBool();
	}
	else static if( isOptional!T )
	{
		T result;
		try
		{
			static if( isDynamicArray!(V) )
			{
				if( value.length > 0 )
					result = conv!(OptionalValueType!T)(value);
			}
			else static if( isUnsafelyNullable!(V) )
			{
				if( value !is null )
					result = conv!(OptionalValueType!T)(value);
			} else {
				result = conv!(OptionalValueType!T)(value);
			}
		} catch( ConvException e ) {
			result = T();
		}

		return result;
	} else static if( !isSomeString!T && isArray!T && isSomeString!V ) {
		if( value.startsWith('{') ) {
			// Parsing of array passed by PostgreSQL
			return value.parse!T('{', '}');
		} else {
			return value.to!T;
		}
	} else {
		return value.to!T;
	}
}

/++
$(LANG_EN
	Function converts character of hex number to byte
)
$(LANG_RU
	Преобразование символа соотв. шестнадцатеричной цифре в байт
)
+/
ubyte hexSymbolToByte(char symbol)
{
	if( symbol >= '0' && symbol <= '9' )
		return cast(ubyte) ( symbol - '0' ) ;
	else if( symbol >= 'a' && symbol <= 'f' )
		return cast(ubyte) ( symbol - 'a' + 10 );
	else if( symbol >= 'A' && symbol <= 'F' )
		return cast(ubyte) ( symbol - 'A' + 10 );
	return 0; //TODO: Подумать, что делать
}

/++
$(LANG_EN
	Function checks if character corresponds to hex number
)
$(LANG_RU
	Функция определяет соответствует ли переданный символ цифре шестнадцатеричного числа
)
+/
bool isHexSymbol(char symbol) {
	return (symbol >= '0' && symbol <= '9') || (symbol >= 'a' && symbol <= 'f') || (symbol >= 'A' && symbol <= 'F');
}

/++
$(LANG_EN
	Function converts string corresponding to hex number into byte array representing this number
)
	$(LANG_RU
	Функция преобразует строку соответствующую шестнадцатеричному числу в массив байтов пердставляющих число
)
+/
ubyte[] hexStringToByteArray(string hexString)
{	auto result = new ubyte[hexString.length/2]; //Выделяем с запасом (в строке могут быть "лишние" символы)
	size_t i = 0; //Индексация результирующего массива
	bool low = false;
	foreach( symbol; hexString )
	{
		if( isHexSymbol(symbol) )
		{
			if( low )
			{
				result[i] += cast(ubyte) hexSymbolToByte(symbol);
				i++; //После добавления младшего символа переходим к след. элементу
			} else {
				result[i] = cast(ubyte) ( hexSymbolToByte(symbol) * 16 );
			}
			low = !low;
		}
	}
	if( low )
		throw new Exception("Количество значащих Hex-символов должно быть чётным");
	//assert( !low, "Количество значащих Hex-символов должно быть чётным" );
 	result.length = i; //Сколько раз перешли, столько реально элементов
	return result;
}

/++
	ditto
+/
ubyte[arrayLen] hexStringToStaticByteArray(size_t arrayLen)(string hexString)
{
	ubyte[arrayLen] result;
	size_t i = 0; //Индексация результирующего массива
	bool low = false;
	foreach( symbol; hexString )
	{
		if( isHexSymbol(symbol) )
		{
			if( i >= arrayLen ) {
				new Exception("Количество значащих символов слишком велико для соответствия размеру результата");
			}
			if( low )
			{
				result[i] += cast(ubyte) hexSymbolToByte(symbol);
				i++; //После добавления младшего символа переходим к след. элементу
			} else {
				result[i] = cast(ubyte) ( hexSymbolToByte(symbol) * 16 );
			}
			low = !low;
		}
	}
	if( low ) {
		throw new Exception("Количество значащих Hex-символов должно быть чётным");
	}
	return result;
}

/++
$(LANG_EN
	Function converts very long number into it's hex string representation
)
	$(LANG_RU
	Функция преобразует очень длинное число в строку, сотоящую из шестнадцатеричных цифр числа
)
+/
string toHexString(uint arrayLen)(ubyte[arrayLen] srcArray)
{
	import std.digest.digest;
	return std.digest.toHexString(srcArray).idup;
}

unittest
{
	import std.digest.md;
	import std.digest;
	ubyte[16] hash = md5Of("abc");
	string hexStr = std.digest.toHexString(hash);
	ubyte[16] restoredHash = hexStringToByteArray(hexStr);
	assert( restoredHash == hash );

	string hexStr2 = "b1e37dab-1c9a-faa5-6d03-9cb3e4399261";
	ubyte[16] hash2 = hexStringToByteArray(hexStr2);
	string restoredHexStr2 = toHexString(hash2);
	ubyte[16] hash2_1 = hexStringToByteArray(restoredHexStr2);
	assert( hash2_1 == hash2 );

	string hexDigits = "0123456789ABCDEFabcdef";
	ubyte[] digits;
	foreach(s; hexDigits)
		digits ~= hexSymbolToByte(s);
	assert( [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 10, 11, 12, 13, 14, 15] == digits);
}

/++
$(LANG_EN
	String values representing values that treated as boolean true value
)
	$(LANG_RU
	Строковые значения, которые трактуются как true при преобразовании типов
)
+/

static immutable trueStrings = [
	`true`, `t`, `yes`, `y`, `истина`, `и`, `да`, `д`, `on`, `1`
];

static immutable falseStrings = [
	`false`, `f`, `no`, `n`, `ложь`, `л`, `нет`, `н`, `off`, `0`
];

/++
$(LANG_EN
	Function converts some string values into boolean value
)
	$(LANG_RU
	Функция преобразования некоторых строковых значений в логическое
)
+/
bool toBool(S)(S src)
{
	import std.string;
	foreach( logicStr; trueStrings )
		if( toLower( strip(src) ) == logicStr )
			return true;
	foreach( logicStr; falseStrings )
		if( toLower( strip(src) ) == logicStr )
			return false;
	import std.conv;
	throw new std.conv.ConvException("Can't convert string \"" ~ src ~ "\" to boolean type!!!");
}

import std.datetime;
/++
$(LANG_EN
	Function converts string of PostgreSQL timestamp into D std.datetime.DateTime
)
	$(LANG_RU
	Функция преобразует строку штампа времени PostgreSQL в формат дата/время языка D
)
+/
auto fromPGTimestamp(T)(const(char)[] value)
{
	import std.algorithm: splitter;
	auto spl = value.splitter!( (ch) { return ch == 'T' || ch == ' '; } );
	assert( !spl.empty, `Splitted date or time string is empty!` );

	static if( is(Unqual!T == DateTime) || is(Unqual!T == SysTime) )
	{
		assert( spl.front.length == 10 );
		auto tmp = spl.front;
		spl.popFront();
		assert( spl.front.length >= 8 );
		static if( is(Unqual!T == DateTime) ) {
			tmp ~= "T" ~ spl.front[0..8]; // Trim the rest of string (milliseconds and timezone). Is it correct?
		} else {
			tmp ~= "T" ~ spl.front;
		}
	}
	else static if( is(Unqual!T == TimeOfDay) )
	{
		auto tmp = spl.front; // Maybe it has date part and we will skip it
		spl.popFront();
		if( !spl.empty ) {
			tmp = spl.front[]; // No it doesn't have date part
		}
		assert( tmp.length >= 8 );
		tmp = tmp[0..8];
	}
	else static if( is(Unqual!T == Date) )
	{
		assert( spl.front.length == 10 );
		auto tmp = spl.front;
	} else {
		static assert(false);
	}
	return T.fromISOExtString(tmp);
}

unittest
{
	string timestamp1 = "2017-10-21 12:59:34.196246+04";
	assert(timestamp1.fromPGTimestamp!DateTime().toISOExtString() == "2017-10-21T12:59:34");
	assert(timestamp1.fromPGTimestamp!Date().toISOExtString() == "2017-10-21");
	assert(timestamp1.fromPGTimestamp!SysTime().toISOExtString() == "2017-10-21T12:59:34.196246+04:00");
	assert(timestamp1.fromPGTimestamp!TimeOfDay().toISOExtString() == "12:59:34");

}