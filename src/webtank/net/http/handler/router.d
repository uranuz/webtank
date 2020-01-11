module webtank.net.http.handler.router;

import webtank.net.http.handler.iface: ICompositeHTTPHandler;

class HTTPRouter: ICompositeHTTPHandler
{
	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.handler.iface: HTTPHandlingResult;
	import webtank.net.http.handler.mixins: EventBasedHTTPHandlerImpl, BaseCompositeHTTPHandlerImpl;

	mixin EventBasedHTTPHandlerImpl;
	mixin BaseCompositeHTTPHandlerImpl;

	HTTPHandlingResult customProcessRequest(HTTPContext context)
	{
		// TODO: Проверить, что имеем достаточно корректный HTTP-запрос
		onPostPoll.fire(context, true);

		foreach( hdl; _handlers )
		{
			if( hdl.processRequest(context) == HTTPHandlingResult.handled ) {
				return HTTPHandlingResult.handled;
			}
		}

		return HTTPHandlingResult.unhandled;
	}

	import std.json: JSONValue;

	override JSONValue toStdJSON()
	{
		import webtank.common.std_json.to: toStdJSON;
		return JSONValue([
			`kind`: JSONValue(typeof(this).stringof),
			`children`: handlersToStdJSON()
		]);
	}
}