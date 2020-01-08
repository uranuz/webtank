module webtank.net.http.http;

public import webtank.net.http.consts: HTTPStatus, HTTPReasonPhrases;

// HTTP exception
class HTTPException: Exception
{
	this(string msg, ushort statusCode, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
		_HTTPStatusCode = statusCode;
	}

	ushort HTTPStatusCode() @property {
		return _HTTPStatusCode;
	}

protected:
	ushort _HTTPStatusCode;
}

// Bad request HTTP exception
class HTTPBadRequest: HTTPException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, HTTPStatus.BadRequest, file, line);
	}
}

// Internal Server Error HTTP Exception
class HTTPInternalServerError: HTTPException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, HTTPStatus.InternalServerError, file, line);
	}
}

// CTL            = <any US-ASCII control character
//                        (octets 0 - 31) and DEL (127)>
// std.ascii.isControl


// separators     = "(" | ")" | "<" | ">" | "@"
//                | "," | ";" | ":" | "\" | <">
//                | "/" | "[" | "]" | "?" | "="
//                | "{" | "}" | SP | HT
bool isHTTPSeparator( dchar c )
{
	import std.algorithm : canFind;
	return `()<>@,;:\"/[]?={}`d.canFind(c) || c == 32 || c == 9;
}

// CHAR           = <any US-ASCII character (octets 0 - 127)>
// std.ascii.isASCII

//token          = 1*<any CHAR except CTLs or separators>
bool isHTTPTokenChar(dchar c )
{
	import std.ascii: isASCII, isControl;
	return ( isASCII(c) && !isControl(c) && !isHTTPSeparator(c) );
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
	static immutable monthNames = [
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	];

	static immutable wkdayNames = [
		"Sun", "Mon", "Tue", "Wed",
		"Thu", "Fri", "Sat"
	];
}

import std.datetime: DateTime, Date, TimeOfDay;

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

DateTime parseHTTPDateTime(T)(ref T input)
{
	import std.datetime: parseRFC822DateTime;
	// TODO: Реализовать разбор других форматов даты/ времени для большей совместимости
	return cast(DateTime) parseRFC822DateTime(input);
}