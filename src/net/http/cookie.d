module webtank.net.http.cookie;

import webtank.net.uri, webtank.net.http.http;

import std.stdio;

//  cookie-octet      = %x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E
//                        ; US-ASCII characters excluding CTLs,
//                        ; whitespace DQUOTE, comma, semicolon,
//                        ; and backslash
bool isCookieOctet( dchar c )
{	import std.ascii;
	return ( isASCII(c) && !isControl(c) && (c != '\"') && (c != ',') && (c != ';') && (c != '/') );
}

// token          = 1*<any CHAR except CTLs or separators>
// separators     = "(" | ")" | "<" | ">" | "@"
//                      | "," | ";" | ":" | "\" | <">
//                      | "/" | "[" | "]" | "?" | "="
//                      | "{" | "}" | SP | HT
alias isHTTPTokenChar isCookieTokenChar;

import std.range, std.algorithm, std.conv;

private {
	// pop char from input range, or throw
	dchar popChar(T)(ref T input)
	{	dchar result = input.front;
		input.popFront();
		return result;
	}

	void consume(T)(ref T input, dchar c)
	{	import std.conv;
		if( popChar(input) != c )
			throw new Exception("expected '" ~ c.to!string  ~ "' character");
	}
}


T[T] parseRequestCookies(T)(T input)
{	T[T] result;

	while( !input.empty )
	{	if( result.length > 0 )
		{	input.consume(';');
			input.consume(' ');
		}
		
		auto name = parseCookieName(input);
		input.consume('=');
		auto value = parseCookieValue(input);
		result[name] = value;
	}
	return result;
}

// cookie-name       = token
T parseCookieName(T)( ref T input )
{	auto temp = input.save();
	size_t count = 0;
	for( ; !input.empty; input.popFront(), count++ )
	{	if( !isCookieTokenChar(input.front) )
			break;
	}

	return temp.take(count).to!T;
}

// cookie-value      = *cookie-octet / ( DQUOTE *cookie-octet DQUOTE )
T parseCookieValue(T)( ref T input )
{	bool isQuotedValue = false;
	
	if( input.front == '\"' )
	{	isQuotedValue = true;
		input.popFront();
	}

	auto temp = input.save();
	size_t count = 0;
		
	for( ; !input.empty; input.popFront(), count++ )
	{	if( !isCookieOctet(input.front) )
			break;
	}

	if( isQuotedValue && popChar(input) != '\"' )
		throw new Exception(`" expected!!!`);

	return temp.take(count).to!T;
}

import std.datetime;
import webtank.common.optional;


// Sun, 06 Nov 1994 08:49:37 GMT  ; RFC 822, updated by RFC 1123

// HTTP-date    = rfc1123-date | rfc850-date | asctime-date
//        rfc1123-date = wkday "," SP date1 SP time SP "GMT"
//        rfc850-date  = weekday "," SP date2 SP time SP "GMT"
//        asctime-date = wkday SP date3 SP time SP 4DIGIT
//        date1        = 2DIGIT SP month SP 4DIGIT
//                       ; day month year (e.g., 02 Jun 1982)
//        date2        = 2DIGIT "-" month "-" 2DIGIT
//                       ; day-month-year (e.g., 02-Jun-82)
//        date3        = month SP ( 2DIGIT | ( SP 1DIGIT ))
//                       ; month day (e.g., Jun  2)
//        time         = 2DIGIT ":" 2DIGIT ":" 2DIGIT
//                       ; 00:00:00 - 23:59:59
//        wkday        = "Mon" | "Tue" | "Wed"
//                     | "Thu" | "Fri" | "Sat" | "Sun"
//        weekday      = "Monday" | "Tuesday" | "Wednesday"
//                     | "Thursday" | "Friday" | "Saturday" | "Sunday"
//        month        = "Jan" | "Feb" | "Mar" | "Apr"
//                     | "May" | "Jun" | "Jul" | "Aug"
//                     | "Sep" | "Oct" | "Nov" | "Dec"
private {
	enum monthNames = [
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	];

	enum wkdayNames = [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ];
}


string toRFC1123DateTimeString(ref DateTime date)
{	return wkdayNames[date.dayOfWeek] ~ ", "
		~ ( date.day > 9 ? "" : "0" ) ~ date.day.to!string ~ " "
		~ monthNames[date.month] ~ " " ~ date.year.to!string ~ " "
		~ ( date.hour > 9 ? "" : "0" ) ~ date.hour.to!string ~ ":"
		~ ( date.minute > 9 ? "" : "0" ) ~ date.minute.to!string ~ ":"
		~ ( date.second > 9 ? "" : "0" ) ~ date.second.to!string ~ " GMT";
}


///Cookie ответа HTTP сервера
struct Cookie
{	string name;
	string value;
	string path;
	string domain;
	Optional!(Duration) maxAge;
	Optional!(DateTime) expires;
	bool isHTTPOnly;
	bool isSecure;

	void opAssign(string rhs)
	{	value = rhs; }

	string toString()
	{	string result = `Set-Cookie: ` ~ name  ~ `=` ~ value;
		if( !expires.isNull )
			result ~= `; Expires=` ~ toRFC1123DateTimeString(expires);
		if( !maxAge.isNull )
			result ~= `; Max-Age=` ~ maxAge.total!("seconds").to!string;
		if( domain.length > 0 )
			result ~= `; Domain=` ~ domain;
		if( path.length > 0 )
			result ~= `; Path=` ~ path;
		if( isHTTPOnly )
			result ~= `; HttpOnly`;
		if( isSecure )
			result ~= `; Secure`;
		return result;
	}
}

///Набор Cookie ответа HTTP сервера
class ResponseCookies
{	import core.exception : RangeError;
protected:
	Cookie[] _cookies;

public:

	///Оператор для установки cookie с именем name значения value
	///Создает новое Cookie, если не существует, или заменяет значение существующего
	void opIndexAssign( string value, string name ) nothrow
	{	auto cookie = name in this;
		if( cookie )
			cookie.value = value;
		else
			_cookies ~= Cookie(name, value);
	}

	///Оператор для установки cookie с помощью структуры Cookie.
	///Добавлет новый элемент Cookie или заменяет существующий элемент,
	///если существует элемент с таким же именем Cookie.name
	void opOpAssign(string op)( ref const(Cookie) value ) nothrow
		if( op == "~" ) 
	{	auto cookie = value.name in this;
		if( cookie )
			*cookie = value;
		else
			_cookies ~= value;
	}

	///Оператор получения доступа к Cookie по имени
	///Бросает исключение RangeError, если Cookie не существует
	ref inout(Cookie) opIndex(string name) inout
	{	auto cookie = name in this;
		if( cookie is null )
			throw new RangeError("Non-existent cookie: "~name);

		return *cookie;
	}

	///Оператор in для ResponseCookies
	inout(Cookie)* opBinaryRight(string op)(string name) inout
		if( op == "in" )
	{	foreach( i, ref c; _cookies )
			if( c.name == name )
				return &_cookies[i];
		return null;
	}

	override string toString()
	{	string result;
		foreach( i, ref cookie; _cookies )
			result ~= ( i > 0 ? "\r\n" : "" ) ~ cookie.toString();
		return result;
	}

	size_t length() @property
	{	return _cookies.length;
	}

	void clear()
	{	_cookies = null;
	}
}


// void main()
// {	import std.stdio;
// 	dstring src = "PREF=\"ID=0bb9e0ce1fb4c67f:U=a6ca966c27393223:FF=0:NW=1:TM=1395815908:LM=1395816213:S=PrfMuivzlOSiy6xD\"; NID=67=cXEBCL3rULR7vZDjTLjceqPWq0GPvb7Ddjnc_D3AbLpQU-OvESEHEb-eO68EURyfxdVePdIlRDt3tbQ63Raue4apE5wE-vHSSa3ZyW2E-45z96HKAYWRp6m7nthkUrM7; OGPC=5061173-4:265001-1:"d;
// 	
// 	auto cooks = parseRequestCookies(src);
// 	
// 	foreach( cook; cooks )
// 		writeln(cook);
// 
// 	auto rpc = new ResponseCookies;
// 	rpc["vasya"] = "petya";
// 	rpc["vova"] = "kotya";
// 	writeln(rpc.toString());
// }