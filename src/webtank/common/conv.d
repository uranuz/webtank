module webtank.common.conv;

/++
$(LOCALE_EN_US
	Function converts character of hex number to byte
)

$(LOCALE_RU_RU
	Преобразование символа соотв. шестнадцатеричной цифре в байт
)
+/
ubyte hexSymbolToByte(char symbol)
{	if( symbol >= '0' && symbol <= '9' )
		return cast(ubyte) ( symbol - '0' ) ;
	else if( symbol >= 'a' && symbol <= 'f' )
		return cast(ubyte) ( symbol - 'a' + 10 );
	else if( symbol >= 'A' && symbol <= 'F' )
		return cast(ubyte) ( symbol - 'A' + 10 );
	return 0; //TODO: Подумать, что делать
}

/++
$(LOCALE_EN_US
	Function checks if character corresponds to hex number
)

$(LOCALE_RU_RU
	Функция определяет соответствует ли переданный символ цифре шестнадцатеричного числа
)
+/
bool isHexSymbol(char symbol)
{	return 
		( symbol >= '0' && symbol <= '9' ) || ( symbol >= 'a' && symbol <= 'f' ) || ( symbol >= 'A' && symbol <= 'F' );
}

/++
$(LOCALE_EN_US
	Function converts string corresponding to hex number into byte array representing this number
)

$(LOCALE_RU_RU
	Функция преобразует строку соответствующую шестнадцатеричному числу в массив байтов пердставляющих число
)
+/
ubyte[] hexStringToByteArray(string hexString)
{	auto result = new ubyte[hexString.length/2]; //Выделяем с запасом (в строке могут быть "лишние" символы)
	size_t i = 0; //Индексация результирующего массива
	bool low = false;
	foreach( symbol; hexString )
	{	if( isHexSymbol(symbol) )
		{	if( low )
			{	result[i] += cast(ubyte) hexSymbolToByte(symbol);
				i++; //После добавления младшего символа переходим к след. элементу
			}
			else
				 result[i] = cast(ubyte) ( hexSymbolToByte(symbol) * 16 );
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
{	ubyte[arrayLen] result;
	size_t i = 0; //Индексация результирующего массива
	bool low = false;
	foreach( symbol; hexString )
	{	if( isHexSymbol(symbol) )
		{	if( i >= arrayLen )
				new Exception( "Количество значащих символов слишком велико для соответствия размеру результата" );
			if( low )
			{	result[i] += cast(ubyte) hexSymbolToByte(symbol);
				i++; //После добавления младшего символа переходим к след. элементу
			}
			else
				 result[i] = cast(ubyte) ( hexSymbolToByte(symbol) * 16 );
			low = !low; 
		}
	}
	if( low )
		throw new Exception("Количество значащих Hex-символов должно быть чётным");
	return result;
}

/++
$(LOCALE_EN_US
	Function converts very long number into it's hex string representation
)

$(LOCALE_RU_RU
	Функция преобразует очень длинное число в строку, сотоящую из шестнадцатеричных цифр числа
)
+/
string toHexString(uint arrayLen)(ubyte[arrayLen] srcArray)
{	import std.digest.digest;
	return std.digest.digest.toHexString(srcArray).idup;
}

unittest
{	import std.digest.md;
	import std.digest.digest;
	ubyte[16] hash = md5Of("abc");
	string hexStr = std.digest.digest.toHexString(hash);
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

enum trueStrings = 
[`true`, `t`, `yes`, `y`, `истина`, `и`, `да`, `д`, `on`, `1`];
enum falseStrings = 
[`false`, `f`, `no`, `n`, `ложь`, `л`, `нет`, `н`, `off`, `0`];

/++
$(LOCALE_EN_US
	Function converts some string values into boolean value
)

$(LOCALE_RU_RU
	Функция преобразования некоторых строковых значений в логическое
)
+/
bool toBool(string src)
{	import std.string;
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
$(LOCALE_EN_US
	Function converts string of PostgreSQL timestamp into D std.datetime.DateTime
)

$(LOCALE_RU_RU
	Функция преобразует строку штампа времени PostgreSQL в формат дата/время языка D
)
+/
DateTime DateTimeFromPGTimestamp( const(char)[] dateString )
{	auto temp = dateString[0..10] ~ "T" ~ dateString[11..19];
	return DateTime.fromISOExtString(temp);
}

// void main()
// {	import std.stdio;
// 	import std.digest.digest;
// 	string hexStr2 = "b1e37dab-1c9a-faa5-6d03-9cb3e4399261";
// 	ubyte[16] hash2 = hexStringToByteArray(hexStr2);
// 	string restoredHexStr2 = toHexString(hash2);
// 	ubyte[16] hash2_1 = hexStringToByteArray(restoredHexStr2);
// 	writeln(hash2);
// 	writeln(restoredHexStr2);
// 	writeln( hash2_1 );
// 	writeln( convDef!bool(" p ", true) );
// 	
// }
