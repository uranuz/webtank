module webtank.net.http.cookie;

import webtank.net.uri, webtank.net.http.http;

//  cookie-octet      = %x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E
//                        ; US-ASCII characters excluding CTLs,
//                        ; whitespace DQUOTE, comma, semicolon,
//                        ; and backslash
bool isCookieOctet( dchar c )
{
	import std.ascii;
	return ( isASCII(c) && !isControl(c) && (c != '\"') && (c != ',') && (c != ';') && (c != '/') );
}

// token          = 1*<any CHAR except CTLs or separators>
// separators     = "(" | ")" | "<" | ">" | "@"
//                      | "," | ";" | ":" | "\" | <">
//                      | "/" | "[" | "]" | "?" | "="
//                      | "{" | "}" | SP | HT
alias isCookieTokenChar = isHTTPTokenChar;

private {
	// pop char from input range, or throw
	dchar popChar(T)(ref T input)
	{
		import std.range: front, popFront;
		dchar result = input.front;
		input.popFront();
		return result;
	}

	void consume(T)(ref T input, dchar c)
	{
		import std.conv: to;
		if( popChar(input) != c )
			throw new HTTPException("Expected '" ~ c.to!string ~ "' character when parsing cookies", 400);
	}
}


CookieCollection parseRequestCookies(T)(T input)
{
	import std.range: empty;
	Cookie[] items;

	while( !input.empty )
	{
		if( !items.empty )
		{
			input.consume(';');
			input.consume(' ');
		}
		
		auto name = parseCookieName(input);
		input.consume('=');
		auto value = parseCookieValue(input);
		items ~= Cookie(name, value);
	}

	return new CookieCollection(items);
}

// cookie-name       = token
T parseCookieName(T)( ref T input )
{
	import std.range: empty, save, popFront, front, take;
	import std.conv: to;

	auto temp = input.save();
	size_t count = 0;
	for( ; !input.empty; input.popFront(), count++ )
	{
		if( !isCookieTokenChar(input.front) )
			break;
	}

	return temp.take(count).to!T;
}

// cookie-value      = *cookie-octet / ( DQUOTE *cookie-octet DQUOTE )
T parseCookieValue(T)( ref T input )
{
	import std.range: empty, save, popFront, front, take;
	import std.conv: to;
	
	bool isQuotedValue = false;
	
	if( input.front == '\"' )
	{
		isQuotedValue = true;
		input.popFront();
	}

	auto temp = input.save();
	size_t count = 0;
		
	for( ; !input.empty; input.popFront(), count++ )
	{
		if( !isCookieOctet(input.front) )
			break;
	}

	if( isQuotedValue && popChar(input) != '\"' )
		throw new HTTPException(`Expected pair quote in cookie value!!!`, 400);

	return temp.take(count).to!T;
}




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

import std.datetime: DateTime;

string toRFC1123DateTimeString(ref DateTime date)
{
	import std.conv: to;
	return wkdayNames[date.dayOfWeek] ~ ", "
		~ ( date.day > 9 ? "" : "0" ) ~ date.day.to!string ~ " "
		~ monthNames[date.month] ~ " " ~ date.year.to!string ~ " "
		~ ( date.hour > 9 ? "" : "0" ) ~ date.hour.to!string ~ ":"
		~ ( date.minute > 9 ? "" : "0" ) ~ date.minute.to!string ~ ":"
		~ ( date.second > 9 ? "" : "0" ) ~ date.second.to!string ~ " GMT";
}


///Cookie ответа HTTP сервера
struct Cookie
{
	import webtank.common.optional;
	import std.range: empty;
	import std.conv: to;

private:
	string _name;
	string _value;
	string[string] _values;

public:
	this(string name, string value) nothrow
	{
		_name = name;
		_value = value;
	}

	string name() inout nothrow @property {
		return _name;
	}
	void name(string val) nothrow @property {
		_name = val;
	}

	string value() inout nothrow @property {
		return _value;
	}
	void value(string val) nothrow @property {
		_value = val;
	}

	string path() inout @property {
		return _values.get("Path", null);
	}
	void path(string val) @property {
		_values["Path"] = val;
	}

	string domain() @property {
		return _values.get("Domain", null);
	}
	void domain(string val) @property {
		_values["Domain"] = val;
	}

	string expires() @property {
		return _values.get("Expires", null);
	}
	void expires(string val) @property {
		_values["Expires"] = val;
	}

	Optional!(DateTime) expiresDate() @property
	{
		import std.datetime: parseRFC822DateTime;
		auto valPtr = "Expires" in _values;
		if( valPtr && !(*valPtr).empty )
			return optional( cast(DateTime) parseRFC822DateTime(*valPtr) );

		return Optional!(DateTime).init;
	}
	void expiresDate(Optional!(DateTime) val) @property
	{
		if( val.isNull ) {
			_values["Expires"] = null;
		} else {
			_values["Expires"] = toRFC1123DateTimeString(val);
		}
	}

	string maxAge() @property {
		return _values.get("Max-Age", null);
	}
	void maxAge(string val) @property {
		_values["Max-Age"] = val;
	}

	import std.datetime: Duration;
	Optional!(Duration) maxAgeDuration() @property
	{
		import std.datetime: dur;
		auto valPtr = "Max-Age" in _values;
		if( valPtr && !(*valPtr).empty )
			return optional( (*valPtr).to!long().dur!"seconds"() );

		return Optional!(Duration).init;
	}
	void maxAgeDuration(Optional!(Duration) val) @property {
		if( val.isNull ) {
			_values["Max-Age"] = null;
		} else {
			_values["Max-Age"] = val.total!("seconds").to!string;
		}
	}

	bool isHTTPOnly() @property {
		return !!_values.get("HttpOnly", null);
	}
	void isHTTPOnly(bool val) @property {
		_values["HttpOnly"] = ( val ? "true" : null );
	}

	bool isSecure() @property {
		return !!_values.get("Secure", null);
	}
	void isSecure(bool val) @property {
		_values["Secure"] = ( val ? "true" : null );
	}

	ref string[string] values() @property {
		return _values;
	}

	void opAssign(string rhs)
	{	_value = rhs; }

	private static immutable _reservedAttrNames = ["Expires", "Max-Age" ,"Domain", "Path", "HttpOnly", "Secure"];
	
	string toString()
	{
		string result = _name ~ `=` ~ _value;

		import std.algorithm: canFind;
		foreach( attrName, attrValue; _values )
		{
			if( _reservedAttrNames.canFind(attrName) )
				continue;
			
			result ~= `; ` ~ attrName ~ `=` ~ attrValue;
		}

		// Following parts should be empty for request headers
		if( !expires.empty )
			result ~= `; Expires=` ~ expires;
		if( !maxAge.empty )
			result ~= `; Max-Age=` ~ maxAge;
		if( !domain.empty )
			result ~= `; Domain=` ~ domain;
		if( !path.empty )
			result ~= `; Path=` ~ path;
		if( isHTTPOnly )
			result ~= `; HttpOnly`;
		if( isSecure )
			result ~= `; Secure`;
		
		return result;
	}
}

///Набор HTTP Cookie
class CookieCollection
{	import core.exception : RangeError;
protected:
	Cookie[] _cookies;

public:
	this() {}

	this( Cookie[] cookies )
	{
		_cookies = cookies;
	}

	///Оператор для установки cookie с именем name значения value
	///Создает новое Cookie, если не существует, или заменяет значение существующего
	void opIndexAssign( string value, string name ) nothrow
	{
		auto cookie = name in this;
		if( cookie )
			cookie.value = value;
		else
			_cookies ~= Cookie(name, value);
	}

	///Оператор для установки cookie с помощью структуры Cookie.
	///Добавлет новый элемент Cookie или заменяет существующий элемент,
	///если существует элемент с таким же именем Cookie.name
	void opOpAssign(string op)( Cookie value ) nothrow
		if( op == "~" ) 
	{
		auto cookie = value.name in this;
		if( cookie )
			*cookie = value;
		else
			_cookies ~= value;
	}

	///Оператор получения доступа к Cookie по имени
	///Бросает исключение RangeError, если Cookie не существует
	ref inout(Cookie) opIndex(string name) inout
	{
		auto cookie = name in this;
		if( cookie is null )
			throw new RangeError("Non-existent cookie: "~name);

		return *cookie;
	}

	///Оператор in для CookieCollection
	inout(Cookie)* opBinaryRight(string op)(string name) inout
		if( op == "in" )
	{
		foreach( i, ref c; _cookies )
		{
			if( c.name == name )
				return &_cookies[i];
		}
		return null;
	}

	/// Возвращает значение куки с именем name, если оно существует в наборе.
	/// Иначе возвращает переданное значение defValue
	string get(string name, string defValue = null) inout
	{
		if( auto cookiePtr = name in this )
			return cookiePtr.value;
		
		return defValue;
	}

	int opApply(scope int delegate(ref Cookie) dg)
	{
		int result = 0;
		for( int i = 0; i < _cookies.length; i++ )
		{
			result = dg( _cookies[i] );
			if( result )
				break;
		}
		return result;
	}

	override string toString()
	{
		import std.range: empty;
		string result;
		foreach( ref cookie; _cookies )
			result ~= ( result.empty ? "" : "\r\n" ) ~ cookie.toString();
		return result;
	}

	string toResponseHeadersString()
	{
		import std.range: empty;
		string result;
		foreach( ref cookie; _cookies )
			result ~= ( result.empty ? "" : "\r\n" ) ~ "Set-Cookie: " ~ cookie.toString();
		return result;
	}

	string toRequestHeadersString()
	{
		import std.range: empty;
		string result;
		foreach( ref cookie; _cookies )
			result ~= ( result.empty ? "" : "\r\n" ) ~ "Cookie: " ~ cookie.toString();
		return result;
	}

	string toOneLineString()
	{
		import std.range: empty;
		string result;
		foreach( ref cookie; _cookies )
			result ~= ( result.empty ? null : "; " ) ~ cookie.toString();
		return result;
	}

	size_t length() @property {
		return _cookies.length;
	}

	void clear() {
		_cookies = null;
	}
}
