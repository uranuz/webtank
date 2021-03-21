module webtank.ivy.directive.remote_call;

import ivy.interpreter.directive.utils;

class RemoteCallInterpreter: BaseDirectiveInterpreter
{
	import ivy.types.data.async_result: AsyncResult;

	import webtank.net.std_json_rpc_client: RemoteCallInfo;
	import webtank.ivy.rpc_client: remoteCall;
	import webtank.ivy.directive.utils: extraxtHeaders, getEndpointURI;

	this()
	{
		_symbol = new DirectiveSymbol("remoteCall", [
			DirAttr("service", IvyAttrType.Str),
			DirAttr("endpoint", IvyAttrType.Str),
			DirAttr("method", IvyAttrType.Str),
			DirAttr("params", IvyAttrType.Any)
		]);
	}
	
	override void interpret(Interpreter interp)
	{
		import std.exception: enforce;
		import std.algorithm: canFind;

		string service = interp.getValue("service").str;
		string endpoint = interp.getValue("endpoint").str;
		string method = interp.getValue("method").str;
		IvyData params = interp.getValue("params");

		enforce(
			[IvyDataType.Null, IvyDataType.AssocArray].canFind(params.type),
			"JSON-RPC params field must be object or null");

		IvyData[string] context = interp.getGlobalValue("context").assocArray;

		string[][string] headers = extraxtHeaders(context["forwardHTTPHeaders"]);
		string uri = getEndpointURI(context["endpoints"].assocArray, service, endpoint);

		AsyncResult fResult = new AsyncResult();
		try
		{
			IvyData methodRes = RemoteCallInfo(uri, headers).remoteCall!IvyData(method, params);
			fResult.resolve(methodRes);
		} catch(Exception ex) {
			fResult.reject(ex);
		}
		interp._stack.push(fResult);
	}
}