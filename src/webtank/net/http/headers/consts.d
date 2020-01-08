module webtank.net.http.headers.consts;

enum HTTPHeader
{
	// Заголовки используемые библиотекой
	HTTPVersion = "http-version",
	StatusCode = "status-code",
	ReasonPhrase = "reason-phrase",
	StatusLine = "status-line",
	RequestLine = "request-line",
	Method = "method",
	RequestURI = "request-uri",

	// Стандартные заголовки
	Accept = "accept",
	AcceptLanguage = "accept-language",
	Connection = "connection",
	ContentType = "content-type",
	ContentLength = "content-length",
	Cookie = "cookie",
	SetCookie = "set-cookie",
	Forwarded = "forwarded",
	Host = "host",
	Location = "location",
	Referer = "referer",
	UserAgent = "user-agent",

	// Расширенные заголовки
	XRealIP = "x-real-ip",
	XForwardedFor = "x-forwarded-for",
	XForwardedProto = "x-forwarded-proto",
	XForwardedHost = "x-forwarded-host",
	XForwardedPort = "x-forwarded-port"
}

// Список спец. заголовков, используемых библиотекой
static immutable internalHeaderNames = [
	// Поля для ответа HTTP-сервера
	HTTPHeader.StatusLine,
	HTTPHeader.HTTPVersion,
	HTTPHeader.StatusCode,
	HTTPHeader.ReasonPhrase,

	// Поля для запроса HTTP-клиента
	HTTPHeader.RequestLine,
	HTTPHeader.Method,
	HTTPHeader.RequestURI
];