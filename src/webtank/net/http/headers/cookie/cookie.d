module webtank.net.http.headers.cookie.cookie;

/// Стандартные аттрибуты для заголовка Set-Cookie
enum SetCookieAttr
{
	Expires = "Expires",
	MaxAge = "Max-Age",
	Domain = "Domain",
	Path = "Path",
	HttpOnly = "HttpOnly",
	Secure = "Secure"
}

private static immutable _reservedAttrNames = [
	SetCookieAttr.Expires,
	SetCookieAttr.MaxAge,
	SetCookieAttr.Domain,
	SetCookieAttr.Path,
	SetCookieAttr.HttpOnly,
	SetCookieAttr.Secure
];

/// Элемент коллекции HTTP Cookie
struct Cookie
{
	import std.range: empty;
	import std.conv: to;
	import std.datetime: DateTime, dur;

	import webtank.net.http.http: parseHTTPDateTime, toRFC1123DateTimeString;
	import webtank.common.optional: optional, Optional;

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
		return _values.get(SetCookieAttr.Path, null);
	}
	void path(string val) @property {
		_values[SetCookieAttr.Path] = val;
	}

	string domain() @property inout {
		return _values.get(SetCookieAttr.Domain, null);
	}
	void domain(string val) @property {
		_values[SetCookieAttr.Domain] = val;
	}

	string expires() @property inout {
		return _values.get(SetCookieAttr.Expires, null);
	}
	void expires(string val) @property
	{
		import std.range: empty;
		if( val.empty ) {
			_values[SetCookieAttr.Expires] = null;
		} else {
			expiresDate = parseHTTPDateTime(val); // Validate field
		}
	}

	Optional!(DateTime) expiresDate() @property inout
	{
		auto valPtr = SetCookieAttr.Expires in _values;
		if( valPtr && !(*valPtr).empty )
			return optional( parseHTTPDateTime(*valPtr) );

		return typeof(return).init;
	}
	void expiresDate(DateTime val) @property {
		_values[SetCookieAttr.Expires] = toRFC1123DateTimeString(val);
	}

	string maxAge() @property inout {
		return _values.get(SetCookieAttr.MaxAge, null);
	}
	void maxAge(string val) @property
	{
		import std.range: empty;
		if( val.empty ) {
			_values[SetCookieAttr.MaxAge] = null;
		}
		maxAgeDuration = val.to!long().dur!"seconds"();
	}

	import std.datetime: Duration;
	Optional!(Duration) maxAgeDuration() @property inout
	{
		import std.datetime: dur;
		auto valPtr = SetCookieAttr.MaxAge in _values;
		if( valPtr && !(*valPtr).empty )
			return optional( (*valPtr).to!long().dur!"seconds"() );

		return typeof(return).init;
	}
	void maxAgeDuration(Duration val) @property {
		_values[SetCookieAttr.MaxAge] = val.total!("seconds").to!string;
	}

	bool isHTTPOnly() @property inout {
		return !!_values.get(SetCookieAttr.HttpOnly, null);
	}
	void isHTTPOnly(bool val) @property {
		_values[SetCookieAttr.HttpOnly] = val? "true": null;
	}

	bool isSecure() @property inout {
		return !!_values.get(SetCookieAttr.Secure, null);
	}
	void isSecure(bool val) @property {
		_values[SetCookieAttr.Secure] = val? "true": null;
	}

	ref string[string] values() return @property {
		return _values;
	}

	void opAssign(string rhs) {
		_value = rhs;
	}

	string toString() inout
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
