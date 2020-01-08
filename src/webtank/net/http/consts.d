module webtank.net.http.consts;

enum HTTPStatus: ushort
{
	///1xx: Informational
	Continue = 100,
	SwitchingProtocols = 101,
	Processing = 102,

	///2xx: Success
	OK = 200,
	Created = 201,
	Accepted = 202,
	NonAuthoritativeInformation = 203,
	NoContent = 204,
	ResetContent = 205,
	PartialContent = 206,
	MultiStatus = 207,
	IMUsed = 226,

	///3xx: Redirection
	MultipleChoices = 300,
	MovedPermanently = 301,
	Found = 302,
	SeeOther = 303,
	NotModified = 304,
	UseProxy = 305,
	TemporaryRedirect = 307,

	///4xx: Client Error
	BadRequest = 400,
	Unauthorized = 401,
	PaymentRequired = 402,
	Forbidden = 403,
	NotFound = 404,
	MethodNotAllowed = 405,
	NotAcceptable = 406,
	ProxyAuthenticationRequired = 407,
	RequestTimeout = 408,
	Conflict = 409,
	Gone = 410,
	LengthRequired = 411,
	PreconditionFailed = 412,
	PayloadTooLarge = 413,
	RequestURLTooLong = 414,
	UnsupportedMediaType = 415,
	RequestedRangeNotSatisfiable = 416,
	ExpectationFailed = 417,
	IAmATeapot = 418,
	UnprocessableEntity = 422,
	Locked = 423,
	FailedDependency = 424,
	UnorderedCollection = 425,
	UpgradeRequired = 426,
	UnavailableForLegalReasons = 451,
	UnrecoverableError = 456,
	RetryWith = 499,

	///5xx: Server Error
	InternalServerError = 500,
	NotImplemented = 501,
	BadGateway = 502,
	ServiceUnavailable = 503,
	GatewayTimeout = 504,
	HTTPVersionNotSupported = 505,
	VariantAlsoNegotiates = 506,
	InsufficientStorage = 507,
	BandwidthLimitExceeded = 509,
	NotExtended = 510
}

immutable(string[ushort]) HTTPReasonPhrases;

shared static this()
{
	HTTPReasonPhrases = [
		///1xx: Информационные — запрос получен, продолжается процесс
		HTTPStatus.Continue: "Continue",
		HTTPStatus.SwitchingProtocols: "Switching Protocols",
		HTTPStatus.Processing: "Processing",

		///2xx: Успешные коды — действие было успешно получено, принято и обработано
		HTTPStatus.OK: "OK",
		HTTPStatus.Created: "Created",
		HTTPStatus.Accepted: "Accepted",
		HTTPStatus.NonAuthoritativeInformation: "Non-Authoritative Information",
		HTTPStatus.NoContent: "No Content",
		HTTPStatus.ResetContent: "Reset Content",
		HTTPStatus.PartialContent: "Partial Content",
		HTTPStatus.MultiStatus: "Multi-Status",
		HTTPStatus.IMUsed: "IM Used",

		///3xx: Перенаправление — дальнейшие действия должны быть предприняты для того, чтобы выполнить запрос
		HTTPStatus.MultipleChoices: "Multiple Choices",
		HTTPStatus.MovedPermanently: "Moved Permanently",
		HTTPStatus.Found: "Found",
		HTTPStatus.SeeOther: "See Other",
		HTTPStatus.NotModified: "Not Modified",
		HTTPStatus.UseProxy: "Use Proxy",
		HTTPStatus.TemporaryRedirect: "Temporary Redirect",

		///4xx: Ошибка клиента — запрос имеет плохой синтаксис или не может быть выполнен
		HTTPStatus.BadRequest: "Bad Request",
		HTTPStatus.Unauthorized: "Unauthorized",
		HTTPStatus.PaymentRequired: "Payment Required",
		HTTPStatus.Forbidden: "Forbidden",
		HTTPStatus.NotFound: "Not Found",
		HTTPStatus.MethodNotAllowed: "Method Not Allowed",
		HTTPStatus.NotAcceptable: "Not Acceptable",
		HTTPStatus.ProxyAuthenticationRequired: "Proxy Authentication Required",
		HTTPStatus.RequestTimeout: "Request Timeout",
		HTTPStatus.Conflict: "Conflict",
		HTTPStatus.Gone: "Gone",
		HTTPStatus.LengthRequired: "Length Required",
		HTTPStatus.PreconditionFailed: "Precondition Failed",
		HTTPStatus.PayloadTooLarge: "Payload Too Large",
		HTTPStatus.RequestURLTooLong: "Request-URL Too Long",
		HTTPStatus.UnsupportedMediaType: "Unsupported Media Type",
		HTTPStatus.RequestedRangeNotSatisfiable: "Requested Range Not Satisfiable",
		HTTPStatus.ExpectationFailed: "Expectation Failed",
		HTTPStatus.IAmATeapot: "I'm a teapot",
		HTTPStatus.UnprocessableEntity: "Unprocessable Entity",
		HTTPStatus.Locked: "Locked",
		HTTPStatus.FailedDependency: "Failed Dependency",
		HTTPStatus.UnorderedCollection: "Unordered Collection",
		HTTPStatus.UpgradeRequired: "Upgrade Required",
		HTTPStatus.UnavailableForLegalReasons: "Unavailable For Legal Reasons",
		HTTPStatus.UnrecoverableError: "Unrecoverable Error",
		HTTPStatus.RetryWith: "Retry With",

		///5xx: Ошибка сервера — сервер не в состоянии выполнить допустимый запрос
		HTTPStatus.InternalServerError: "Internal Server Error",
		HTTPStatus.NotImplemented: "Not Implemented",
		HTTPStatus.BadGateway: "Bad Gateway",
		HTTPStatus.ServiceUnavailable: "Service Unavailable",
		HTTPStatus.GatewayTimeout: "Gateway Timeout",
		HTTPStatus.HTTPVersionNotSupported: "HTTP Version Not Supported",
		HTTPStatus.VariantAlsoNegotiates: "Variant Also Negotiates",
		HTTPStatus.InsufficientStorage: "Insufficient Storage",
		HTTPStatus.BandwidthLimitExceeded: "Bandwidth Limit Exceeded",
		HTTPStatus.NotExtended: "Not Extended"
	];
}