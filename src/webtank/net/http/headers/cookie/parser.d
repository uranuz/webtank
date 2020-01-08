module webtank.net.http.headers.cookie.parser;

import webtank.net.http.http: isHTTPTokenChar, HTTPBadRequest;

import webtank.net.http.headers.cookie: Cookie, CookieCollection, SetCookieAttr;

//  cookie-octet      = %x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E
//                        ; US-ASCII characters excluding CTLs,
//                        ; whitespace DQUOTE, comma, semicolon,
//                        ; and backslash
bool isCookieOctet(dchar c)
{
	import std.ascii: isASCII, isControl;
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
			throw new HTTPBadRequest("Expected '" ~ c.to!string ~ "' character when parsing cookies");
	}
}


Cookie[] parseCookieHeaderValue(T)(T input)
{
	import std.range: empty;

	Cookie[] items;

	while( !input.empty )
	{
		auto name = parseCookieName(input);
		input.consume('=');
		auto value = parseCookieValue(input);
		items ~= Cookie(name, value);

		if( input.empty )
			break;
		input.consume(';');
		if( input.empty )
			break;
		input.consume(' ');
	}

	return items;
}

// cookie-name       = token
T parseCookieName(T)(ref T input)
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
T parseCookieValue(T)(ref T input)
{
	import std.range: empty, save, popFront, front, take;
	import std.conv: to;

	if( input.empty )
		return null;
	
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
		throw new HTTPBadRequest(`Expected pair quote in cookie value!!!`);

	return temp.take(count).to!T;
}

private
{
	void skipOverCIS(T)(ref T input, auto ref T what)
	{
		import std.algorithm: skipOver;
		import std.uni: asLowerCase;
		if( input.asLowerCase.skipOver(what) )
			return true;
		return false;
	}
}

void _nforceNoDup(bool isDup, string attrName)
{
	import std.exception: enforce;
	enforce!HTTPBadRequest(isDup, `Duplicate "` ~ attrName ~ `" cookie attribute`);
}

// cookie-av         = expires-av / max-age-av / domain-av /
//                     path-av / secure-av / httponly-av /
//                     extension-av
void parseCookieAV(T)(ref T input, Cookie cookie)
{
	import std.exception: enforce;
	import std.algorithm: splitter, findSplit;
	import std.range: empty;

	if( input.empty )
		return;
	input.consume(';');
	if( input.empty )
		return;
	input.consume(' ');

	auto attrSpl = input.splitter(`; `);
	foreach( attrPair; attrSpl )
	{
		auto pairSpl = attrPair.findSplit(`=`);
		string attrName = pairSpl[0];
		string attrValue = pairSpl[2];
		switch( attrName )
		{
			case SetCookieAttr.Expires: {
				_nforceNoDup(cookie.expires.empty, attrName);
				cookie.expires = attrValue;
				break;
			}
			case SetCookieAttr.MaxAge: {
				_nforceNoDup(cookie.maxAge.empty, attrName);
				cookie.maxAge = attrValue;
				break;
			}
			case SetCookieAttr.Domain: {
				_nforceNoDup(cookie.domain.empty, attrName);
				cookie.domain = attrValue;
				break;
			}
			case SetCookieAttr.Path: {
				_nforceNoDup(cookie.path.empty, attrName);
				cookie.path = attrValue;
				break;
			}
			case SetCookieAttr.HttpOnly: {
				// If cookie present then it is true...
				cookie.isHTTPOnly = true;
				break;
			}
			case SetCookieAttr.Secure: {
				cookie.isSecure = true;
				break;
			}
			default: {
				// Неизвестный аттрибут для куки. Проставляем как есть
				cookie.values[attrName] = attrValue;
				break;
			}
		}
	}
}

Cookie parseSetCookieHeaderValue(T)(ref T input)
{
	string name = parseCookieName(input);
	input.consume('=');
	string value = parseCookieValue(input);
	Cookie cookie = Cookie(name, value);

	parseCookieAV(input, cookie);

	return cookie;
}
