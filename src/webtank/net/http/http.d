module webtank.net.http.http;

class HTTPException : Exception {
	this(string msg, ushort statusCode, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
		_HTTPStatusCode = statusCode;
	}

	ushort HTTPStatusCode() @property
	{	return _HTTPStatusCode; }

protected:
	ushort _HTTPStatusCode;
}

// CTL            = <any US-ASCII control character
//                        (octets 0 - 31) and DEL (127)>
// std.ascii.isControl


// separators     = "(" | ")" | "<" | ">" | "@"
//                | "," | ";" | ":" | "\" | <">
//                | "/" | "[" | "]" | "?" | "="
//                | "{" | "}" | SP | HT
bool isHTTPSeparator( dchar c )
{	import std.algorithm : canFind;
	return `()<>@,;:\"/[]?={}`d.canFind(c) || c == 32 || c == 9;
}

// CHAR           = <any US-ASCII character (octets 0 - 127)>
// std.ascii.isASCII

//token          = 1*<any CHAR except CTLs or separators>
bool isHTTPTokenChar(dchar c )
{	import std.ascii;
	return ( isASCII(c) && !isControl(c) && !isHTTPSeparator(c) );
}

immutable(string[ushort]) HTTPReasonPhrases;

shared static this()
{	HTTPReasonPhrases = [
		///1xx: Informational
		///1xx: Информационные — запрос получен, продолжается процесс
		100: "Continue", 101: "Switching Protocols", 102: "Processing",

		///2xx: Success
		///2xx: Успешные коды — действие было успешно получено, принято и обработано
		200: "OK", 201: "Created", 202: "Accepted", 203: "Non-Authoritative Information", 204: "No Content", 205: "Reset Content", 206: "Partial Content", 207: "Multi-Status", 226: "IM Used",

		///3xx: Redirection
		///3xx: Перенаправление — дальнейшие действия должны быть предприняты для того, чтобы выполнить запрос
		300: "Multiple Choices", 301: "Moved Permanently", 302: "Found", 303: "See Other", 304: "Not Modified", 305: "Use Proxy", 307: "Temporary Redirect",

		///4xx: Client Error
		///4xx: Ошибка клиента — запрос имеет плохой синтаксис или не может быть выполнен
		400: "Bad Request", 401: "Unauthorized", 402: "Payment Required", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed", 406: "Not Acceptable", 407: "Proxy Authentication Required", 408: "Request Timeout", 409: "Conflict", 410: "Gone", 411: "Length Required", 412: "Precondition Failed", 414: "Request-URL Too Long", 415: "Unsupported Media Type", 416: "Requested Range Not Satisfiable", 417: "Expectation Failed", 418: "I'm a teapot", 422: "Unprocessable Entity", 423: "Locked", 424: "Failed Dependency", 425: "Unordered Collection", 426: "Upgrade Required", 456: "Unrecoverable Error", 499: "Retry With",

		///5xx: Server Error
		///5xx: Ошибка сервера — сервер не в состоянии выполнить допустимый запрос
		500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway", 503: "Service Unavailable", 504: "Gateway Timeout", 505: "HTTP Version Not Supported", 506: "Variant Also Negotiates", 507: "Insufficient Storage", 509: "Bandwidth Limit Exceeded", 510: "Not Extended"
	];
}