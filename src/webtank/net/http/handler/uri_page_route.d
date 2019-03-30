module webtank.net.http.handler.uri_page_route;

import webtank.net.http.handler.iface: IHTTPHandler;

/// Обработчик для конкретного маршрута к странице сайта
class URIPageRoute: IHTTPHandler
{
	import webtank.net.http.context: HTTPContext;
	import webtank.net.uri_pattern: URIPattern, URIMatchingData;
	import webtank.net.http.handler.iface: HTTPHandlingResult;
protected:
	URIPattern _uriPattern;
	PageHandler _handler;

public:
	alias PageHandler = void delegate(HTTPContext);

	this(PageHandler handler, string uriPatternStr) {
		_handler = handler;
		_uriPattern = new URIPattern(uriPatternStr);
	}
	
	this(PageHandler handler, URIPattern uriPattern) {
		_handler = handler;
		_uriPattern = uriPattern;
	}

	override HTTPHandlingResult processRequest(HTTPContext context)
	{
		URIMatchingData uriMatchData = _uriPattern.match(context.request.uri.path);
		if( !uriMatchData.isMatched )
			return HTTPHandlingResult.mismatched;

		context.request.requestURIMatch = uriMatchData;
		_handler(context);
		return HTTPHandlingResult.handled; // Запрос обработан
	}
}