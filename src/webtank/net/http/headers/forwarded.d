module webtank.net.http.headers.forwarded;

// Реализует разбор и структурированную обработку HTTP-заголовка Forwarded,
// который представлен в данном RFC: https://tools.ietf.org/html/rfc7239

import std.exception: enforce;
import trifle.parse_utils: empty, popFront, front, save;
import webtank.net.http.http: isHTTPTokenChar;

// Хранит данные заголовков Forwarded и предоставляет к ним структурированный доступ
class HTTPForwardedList
{
protected HTTPForwardedElement[] _elems;

public:
	this(HTTPForwardedElement[] elems) {
		fill(elems);
	}

	this(string[] items)
	{
		this(parseForwardedItems(items));
	}

	void fill(HTTPForwardedElement[] elems) pure {
		_elems = elems;
	}

	static struct Range
	{
		private HTTPForwardedList _list;
		private size_t _i = 0;

	public:
		this(HTTPForwardedList list)
		{
			enforce(list !is null, `Expected instance of HTTPForwardedList`);
			_list = list;
		}

		bool empty() @property {
			return _i >= _list._elems.length;
		}

		HTTPForwardedElement front() @property
		{
			enforce(!this.empty, `Unable to get access to front element of empty HTTPForwardedList range`);
			return _list._elems[_i];
		}

		void popFront()
		{
			enforce(!this.empty, `Unable to push forward empty HTTPForwardedList range`);
			++_i;
		}
	}

	Range opSlice() {
		return Range(this);
	}

	inout(string[]) toStringArray() inout
	{
		inout(string)[] forwardedArr;
		foreach( elem; _elems ) {
			forwardedArr ~= elem.toString();
		}
		return cast(inout) forwardedArr;
	}

}

// Перечисление с полями внутри заголовка Forwarded
enum HTTPForwardedField
{
	For = `for`,
	By = `by`,
	Host = `host`,
	Proto = `proto`
}

// Элемент HTTP-заголовка Forwarded
struct HTTPForwardedElement
{
private string[string] _values;

public:
	this(string[string] vals) {
		_values = vals;
	}

	string get(string field) {
		return _values.get(field, null);
	}

	string for_() @property {
		return this.get(HTTPForwardedField.For);
	}

	string by() @property {
		return this.get(HTTPForwardedField.By);
	}

	string host() @property {
		return this.get(HTTPForwardedField.Host);
	}

	string proto() @property {
		return this.get(HTTPForwardedField.Proto);
	}

	string toString() inout
	{
		import std.array: appender;
		import trifle.escaped_string_writer: writeQuotedStr;
		import trifle.parse_utils: save;

		auto res = appender!string();
		foreach( key, value; _values )
		{
			if( res.data.length > 0 ) {
				res.put(`;`);
			}
			res.put(key ~ `=`);
			// Let's determine if we need to quote value first
			auto tmp = value.save;
			bool quote = false;
			while( !tmp.empty )
			{
				if( !isHTTPTokenChar(tmp.front) ) {
					quote = true;
				}
				tmp.popFront();
			}
			writeQuotedStr(res, value, quote);
		}
		return res.data;
	}
}


// Разбирает список значений HTTP-заголовков Forwarded
HTTPForwardedElement[] parseForwardedItems(string[] items)
{
	HTTPForwardedElement[] res;
	
	foreach( item; items )
	{
		while( !item.empty ) {
			res ~= _parseForwardedElement(item);
		}
	}
	return res;
}

void skipWhite(ref string src)
{
	import std.algorithm: canFind;
	for( ; !src.empty; src.popFront() )
	{
		if( !" \t".canFind(src.front) ) {
			break;
		}
	}
}

HTTPForwardedElement _parseForwardedElement(ref string src)
{
	string[string] vals;

	while( !src.empty )
	{
		skipWhite(src);
		string key = _parseToken(src);
		enforce(!src.empty, `Expected forwarded pair delimiter, but got end of input`);
		enforce(src.front == '=', `Expected forwarded pair delimiter`);
		src.popFront(); // Skip =
		enforce(key !in vals, `Duplicate forwarded element fields are not allowed`);
		vals[key] = _parseValue(src);

		if( src.empty ) {
			break;
		}

		if( src.front == ',' )
		{
			src.popFront(); // Skip ,
			break;
		}

		enforce(src.front == ';', `Expected forwarded elements or items delimeter, but got: ` ~ src.front);
		src.popFront(); // Skip ;
	}
	return HTTPForwardedElement(vals);
}

string _parseToken(ref string src)
{
	auto tmp = src.save;
	size_t len = 0;

	for( ; !src.empty; src.popFront(), ++len )
	{
		if( !isHTTPTokenChar(src.front) ) {
			break;
		}
	}
	return tmp[0..len];
}

string _parseValue(ref string src)
{
	if( src.empty ) {
		return null;
	}

	if( src.front == '\"' ) {
		return _parseQuotedString(src);
	}
	return _parseToken(src);
}

string _parseQuotedString(ref string src)
{
	import trifle.quoted_string_range: QuotedStringRange;

	import std.array: appender;

	alias QuotRange = QuotedStringRange!(string, `"`);

	auto buf = appender!string();
	auto qRange = QuotRange(src);
	for( ; !qRange.empty; qRange.popFront() ) {
		buf ~= qRange.front;
	}
	src = qRange.source;

	return buf.data;
}
