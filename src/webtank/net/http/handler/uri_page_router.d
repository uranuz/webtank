module webtank.net.http.handler.uri_page_router;

import webtank.net.http.handler.iface: ICompositeHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.net.uri_pattern: URIPattern;
import webtank.net.http.handler.uri_page_route: URIPageRoute;

/// Маршрутизатор запросов к страницам сайта по URI
class URIPageRouter: ICompositeHTTPHandler
{
	import webtank.net.http.handler.iface: HTTPHandlingResult;
	import webtank.net.uri_pattern: URIPattern, URIMatchingData;

	import webtank.net.http.handler.mixins: EventBasedHTTPHandlerImpl, BaseCompositeHTTPHandlerImpl;
	
	mixin EventBasedHTTPHandlerImpl;
	mixin BaseCompositeHTTPHandlerImpl;

	this(string uriPatternStr) {
		_uriPattern = new URIPattern(uriPatternStr);
	}
	
	this(URIPattern uriPattern) {
		_uriPattern = uriPattern;
	}

	HTTPHandlingResult customProcessRequest(HTTPContext context)
	{
		URIMatchingData uriData = _uriPattern.match(context.request.uri.path);
		if( uriData.isMatched )
			context.request.requestURIMatch = uriData;

		onPostPoll.fire(context, uriData.isMatched);

		if( !uriData.isMatched )
			return HTTPHandlingResult.mismatched;

		// Перебор маршрутов к страницам
		foreach( hdl; _handlers )
		{
			if( hdl.processRequest(context) == HTTPHandlingResult.handled ) {
				return HTTPHandlingResult.handled; // Запрос обработан
			}
		}

		return HTTPHandlingResult.mismatched; // Обработчик для запроса не найден
	}
protected:
	URIPattern _uriPattern;
}

import std.traits: ReturnType, Parameters;
template join(alias Method)
	if(
		is(ReturnType!(Method) == void) && Parameters!(Method).length == 1 && is(Parameters!(Method)[0] : HTTPContext)
	)
{
	import std.functional: toDelegate;
	auto join(ICompositeHTTPHandler parentHdl, string uriPatternStr)
	{
		parentHdl.addHandler(
			new URIPageRoute(cast(void delegate(HTTPContext)) toDelegate(&Method), uriPatternStr)
		);
		return parentHdl;
	}

	auto join(ICompositeHTTPHandler parentHdl, URIPattern uriPattern)
	{
		parentHdl.addHandler(
			new URIPageRoute(cast(void delegate(HTTPContext)) toDelegate(&Method), uriPattern)
		);
		return parentHdl;
	}
}