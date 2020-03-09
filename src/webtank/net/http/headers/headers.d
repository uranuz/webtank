module webtank.net.http.headers.headers;

import webtank.net.http.headers.consts: HTTPHeader, internalHeaderNames;
import webtank.net.http.headers.cookie: CookieCollection, Cookie;
import webtank.net.http.headers.forwarded: HTTPForwardedList;
import webtank.net.http.consts: HTTPStatus, HTTPReasonPhrases;


/// Class is representing HTTP headers for request and response
/// Класс, представляющий HTTP заголовки для запроса и ответа
class HTTPHeaders
{
	import webtank.net.http.headers.cookie.parser: parseCookieHeaderValue, parseSetCookieHeaderValue;
	import webtank.net.http.headers.forwarded: parseForwardedItems;
	import webtank.net.http.http: HTTPInternalServerError;
	
	///HTTP request headers constructor
	///Конструктор для заголовков запроса
	this(string[][string] headers)
	{
		import std.exception: enforce;
		import std.uni: isLower, isAlpha;
		import std.algorithm: all;
		import std.string: strip;
		import std.range: empty;

		_headers = headers;

		Cookie[] cookieList;
		auto cookieArrPtr = HTTPHeader.Cookie in _headers;
		if( cookieArrPtr && cookieArrPtr.length > 0 )
		{
			enforce(isRequest, `Only HTTP request can use "Cookie" header`);
			foreach( cookieStr; (*cookieArrPtr) )
			{
				if( !cookieStr.empty ) {
					cookieList ~= parseCookieHeaderValue(cookieStr);
				}
			}
		}

		auto setCookieArrPtr = HTTPHeader.SetCookie in _headers;
		if( setCookieArrPtr && setCookieArrPtr.length > 0 )
		{
			enforce(!isRequest, `Only HTTP response can use "Set-Cookie" header`);
			foreach( setCookieStr; (*setCookieArrPtr) )
			{
				if( !setCookieStr.empty ) {
					cookieList ~= parseSetCookieHeaderValue(setCookieStr);
				}
			}
		}
		_cookies = new CookieCollection(cookieList);
		_forwarded = new HTTPForwardedList(_headers.get(HTTPHeader.Forwarded, null));

		// Удаляем из общего словаря заголовков поля, которые обрабатываются спец. образом
		_headers.remove(HTTPHeader.Cookie);
		_headers.remove(HTTPHeader.SetCookie);
		_headers.remove(HTTPHeader.StatusLine);
		_headers.remove(HTTPHeader.RequestLine);
		_headers.remove(HTTPHeader.Forwarded);

		foreach( string key, values; headers )
		{
			if( key.strip.empty ) {
				continue; // Just ignore empty header names
			}
			// For the efficiency expect that header names are already normalized.
			// If not then just issue an error...
			enforce!HTTPInternalServerError(
				all!( (ch) => isLower(ch) || !isAlpha(ch) )(key), `Invalid HTTP header name: ` ~ key);
		}
	}

	/// HTTP response headers constructor
	/// Конструктор заголовков ответа
	this()
	{
		this[HTTPHeader.HTTPVersion] = "HTTP/1.0";
		this.statusCode = HTTPStatus.OK;

		_cookies = new CookieCollection(); // Just to make it not null and null-access-safe
	}

	// Возвращает true, если это экземпляр данных о запросе к HTTP-серверу
	// и false - если это ответ, переданный HTTP-клиенту на како-либо запрос
	bool isRequest() @property inout {
		// Если в заголовках адрес запроса - значит это запрос
		return (HTTPHeader.RequestURI in this) !is null;
	}

	string getStartingLine() {
		return this.isRequest? getRequestLine(): getStatusLine();
	}

	///Method for getting status line of HTTP response
	///Метод для получения строки состояния HTTP ответа
	string getStatusLine()
	{
		string sl = this[HTTPHeader.StatusLine];
		return sl.length > 0? (sl ~ "\r\n"): null;
	}

	string getRequestLine()
	{
		string sl = this[HTTPHeader.RequestLine];
		return sl.length > 0? (sl ~ "\r\n"): null;
	}

	void statusCode(ushort code) @property
	{
		import std.conv: text;

		this[HTTPHeader.StatusCode] = code.text;
		this[HTTPHeader.ReasonPhrase] = HTTPReasonPhrases.get(code, `Unknown status code`);
	}

	size_t contentLength() @property {
		return extractContentLength(_headers);
	}

	///Method for getting HTTP headers as string (separated by "\r\n")
	///Метод для получения HTTP заголовков в виде строки (разделённых символами переноса "\r\n")
	string getString()
	{
		import std.algorithm: canFind;

		string result = getStartingLine(); // First of all add starting line
		foreach( name, values; _headers )
		{
			if( internalHeaderNames.canFind(name) )
				continue; // Внутренние заголовки не вываливаем в ответ
			foreach( value; values ) {
				result ~= name ~ ": " ~ value ~ "\r\n";
			}
		}
		result ~= this.cookieHeaderString;
		return result;
	}

	///Operator for writing value of header
	///Оператор записи значения заголовка
	void opIndexAssign(string value, string name) {
		this[name] = [value];
	}

	///Operator for writing multiple values of header
	///Оператор записи множества значений заголовка
	void opIndexAssign(string[] values, string name) {
		this.array(name, values);
	}

	///Operator for reading value of header
	///Оператор чтения значения заголовка
	string opIndex(string name) inout {
		return this.get(name, null);
	}

	///Method gets value of header with "name" or "defaultValue" if header is not exist
	///Метод получает значение заголовка с именем name или defaultValue, если заголовок отсутствует
	string get(string name, string defaultValue) inout
	{
		import std.range: front, empty;
		auto arr = this.array(name);
		return arr.empty? defaultValue: arr.front;
	}

	static immutable _statusLineAttrs = [
		HTTPHeader.HTTPVersion,
		HTTPHeader.StatusCode,
		HTTPHeader.ReasonPhrase
	];
	static immutable _requestLineAttrs = [
		HTTPHeader.Method,
		HTTPHeader.RequestURI,
		HTTPHeader.HTTPVersion
	];

	// Заголовки, которых нет в словаре заголовков, т.к. они рассчитываются на ходу
	static immutable _calculatedHeaders = [
		HTTPHeader.RequestLine,
		HTTPHeader.StatusLine,
		HTTPHeader.Cookie,
		HTTPHeader.SetCookie
	];
	inout(string[]) array(string name) inout
	{
		import std.uni: toLower;
		import std.algorithm: canFind, map, filter;
		import std.string: join;
		import std.range: empty;

		string lowerName = toLower(name);
		switch(lowerName)
		{
			case HTTPHeader.Cookie: case HTTPHeader.SetCookie: {
				if( _cookies is null ) {
					return null; // Ну, нет у нас кук...
				}
				// Отдаем заголовок "Cookie" только, если у нас запрос,
				// а заголовок "SetCookie" только, если у нас ответ
				if( this.isRequest != (lowerName == HTTPHeader.Cookie) ) {
					return null;
				}
				// Получаем массив куков в виде строк
				return _cookies.toStringArray();
			}
			case HTTPHeader.StatusLine: case HTTPHeader.RequestLine: {
				auto self = this;
				auto startLine = (
					lowerName == HTTPHeader.RequestLine?
					_requestLineAttrs: _statusLineAttrs
				).map!(
					(attr) => self[attr]
				).filter!(
					(val) => !val.empty
				).join(' ');
				return [startLine];
			}
			case HTTPHeader.Forwarded: {
				return _forwarded.toStringArray();
			}
			default: break;
		}
		// I just could used "get", but this workaround for `inout hell`
		auto valuesPtr = lowerName in _headers;
		if( valuesPtr )
			return (*valuesPtr);
		return null;
	}

	void array(string name, string[] arr)
	{
		import std.algorithm: canFind;
		import std.uni: toLower;
		import std.exception: enforce;
		import std.string: strip;
		import std.range: empty;

		// Пустые ключи не добавляем
		if( name.strip.empty )
			return;
		string lowerName = toLower(name);
		switch(lowerName)
		{
			case HTTPHeader.Cookie: {
				Cookie[] cookieList;
				foreach( cookieStr; arr )
				{
					if( !cookieStr.empty ) {
						cookieList ~= parseCookieHeaderValue(cookieStr);
					}
				}
				_cookies.fill(cookieList);
				return; // Don't put cookie in _headers
			}
			case HTTPHeader.SetCookie: {
				Cookie[] cookieList;
				foreach( cookieStr; arr )
				{
					if( !cookieStr.empty  ) {
						cookieList ~= parseSetCookieHeaderValue(cookieStr);
					}
				}
				_cookies.fill(cookieList);
				return; // Don't put cookie in _headers
			}
			case HTTPHeader.Forwarded: {
				_forwarded.fill(parseForwardedItems(arr));
				return; // Don't put forwarded in _headers
			}
			default:
				break; 
		}

		if( [HTTPHeader.StatusLine, HTTPHeader.RequestLine].canFind(lowerName) )
			return; // Just ignore setting this headers, because they should be set by subheaders

		_headers[lowerName] = arr;
	}

	///Оператор in для класса
	inout(string)* opBinaryRight(string op)(string name) inout
		if(op == "in")
	{
		auto arr = this.array(name);
		if( arr.length > 0 )
			return &(arr[0]);
		return null;
	}

	/// Returns copy of headers as associative array
	/// Возвращает копию заголовков в виде ассоциативного массива
	string[][string] toAA()
	{
		auto hdr = _headers.dup;
		foreach( string headerName; _calculatedHeaders )
		{
			auto arr = this.array(headerName);
			if( arr.length > 0 ) {
				hdr[headerName] = arr;
			}
		}
		return hdr;
	}

	///Response headers clear method
	///Очистка заголовков ответа
	void clear()
	{
		if( !isRequest )
		{
			_headers.clear();
			_cookies.clear();
		}
	}

	CookieCollection cookies() @property {
		return _cookies;
	}

	private string _cookieRequestString()
	{
		if( _cookies is null )
			return null;

		string ols = _cookies.toOneLineString();
		return ols.length > 0? HTTPHeader.Cookie ~ ": " ~ ols ~ "\r\n": null;
	}

	private string _cookieResponseString()
	{
		import std.string: join;
		import std.algorithm: map;

		if( _cookies is null )
			return null;

		string rhs = _cookies
			.toStringArray()
			.map!( (it) => (HTTPHeader.SetCookie ~ ": " ~ it) )
			.join("\r\n");
		return rhs.length > 0? rhs ~ "\r\n": null;
	}

	string cookieHeaderString() @property {
		return this.isRequest? _cookieRequestString(): _cookieResponseString();
	}

protected:
	string[][string] _headers;
	bool _isRequest;
	CookieCollection _cookies;
	HTTPForwardedList _forwarded;
}

size_t extractContentLength(string[][string] headers)
{
	import std.range: front, empty;
	import std.conv: to, ConvException;
	import std.exception: enforce;

	import webtank.net.http.http: HTTPBadRequest;

	if( auto contentLengthArrPtr = HTTPHeader.ContentLength in headers )
	{
		enforce!HTTPBadRequest(
			contentLengthArrPtr.length > 0,
			`HTTP header "Content-Length" has no value`);
		enforce!HTTPBadRequest(
			contentLengthArrPtr.length == 1,
			`HTTP header "Content-Length" is duplicate`);

		string contentLengthStr = (*contentLengthArrPtr).front;
		if( contentLengthStr.empty ) {
			return 0;
		}

		try {
			return contentLengthStr.to!size_t;
		} catch( ConvException ex ) {
			throw new HTTPBadRequest(`Expected integer in Content-Length header`);
		}
	}
	return 0;
}