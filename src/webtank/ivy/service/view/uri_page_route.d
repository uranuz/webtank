module webtank.ivy.service.view.uri_page_route;

import webtank.net.http.handler.iface: IHTTPHandler;

class ViewServiceURIPageRoute: IHTTPHandler
{
	import webtank.net.http.context: HTTPContext;	
	import webtank.net.http.handler.iface: HTTPHandlingResult;
	import webtank.net.service.config.page_routing: RoutingConfigEntry;

	import webtank.net.uri_pattern: URIPattern;

	import webtank.ivy.service.view.context: IvyViewServiceContext;

	import ivy.types.data: IvyData;

protected:
	RoutingConfigEntry _entry;
	URIPattern _uriPattern;


public:
	this(RoutingConfigEntry entry)
	{
		import std.exception: enforce;
		enforce(entry.isValid, "Invalid RoutingConfigEntry");
		
		_entry = entry;
		_uriPattern = new URIPattern(_entry.pageURI);
	}

	override HTTPHandlingResult processRequest(HTTPContext context)
	{
		import std.exception: enforce;
		auto viewContext = cast(IvyViewServiceContext) context;
		if (viewContext is null)
			return HTTPHandlingResult.mismatched;
		return processViewRequest(viewContext);
	}

	HTTPHandlingResult processViewRequest(IvyViewServiceContext context)
	{
		import std.uni: asLowerCase;
		import std.algorithm: equal;
		import std.range: empty;

		import ivy.types.data.utils: errorToIvyData;

		if( !_entry.HTTPMethod.empty )
		{
			// Filter by HTTP-method if it was specified
			if( !equal(context.request.method.asLowerCase, _entry.HTTPMethod.asLowerCase) )
				return HTTPHandlingResult.mismatched;
		}

		auto uriMatchData = _uriPattern.match(context.request.uri.path);
		if( !uriMatchData.isMatched )
			return HTTPHandlingResult.mismatched;

		context.request.requestURIMatch = uriMatchData;

		context.service.processIvyRequest(context, _entry.ivyModule, _entry.ivyMethod).then(
			(IvyData res) {
				context.service.renderResult(context, res);
			},
			(Throwable error) {
				context.service.renderResult(context, errorToIvyData(error));
			});

		return HTTPHandlingResult.handled; // Запрос обработан
	}

	import std.json: JSONValue;
	override JSONValue toStdJSON()
	{
		import webtank.common.std_json.to: toStdJSON;
		return JSONValue([
			`kind`: JSONValue(typeof(this).stringof),
			`entry`: _entry.toStdJSON()
		]);
	}
}