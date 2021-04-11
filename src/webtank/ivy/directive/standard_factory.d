module webtank.ivy.directive.standard_factory;

import ivy.types.data: IvyData, IvyDataType;
import ivy.interpreter.interpreter: Interpreter;
import ivy.interpreter.directive.factory: InterpreterDirectiveFactory;
import ivy.interpreter.directive.base: makeDir;
import ivy.types.symbol.dir_attr: DirAttr;
import ivy.types.symbol.consts: IvyAttrType;
import ivy.types.data.async_result: AsyncResult;

InterpreterDirectiveFactory webtankDirFactory() @property {
	return _factory;
}

private __gshared InterpreterDirectiveFactory _factory;

shared static this()
{
	import ivy.interpreter.directive.standard_factory: ivyDirFactory;

	// Use ivy factory as a base for webtank factory
	_factory = new InterpreterDirectiveFactory(ivyDirFactory);

	_factory.add(makeDir!optStorageFn("optStorage", [
		DirAttr("opts", IvyAttrType.Any)
	]));
	_factory.add(makeDir!remoteCallFn("remoteCall", [
		DirAttr("service", IvyAttrType.Str),
		DirAttr("endpoint", IvyAttrType.Str),
		DirAttr("method", IvyAttrType.Str),
		DirAttr("params", IvyAttrType.Any)
	]));
	_factory.add(makeDir!toJSONBase64Fn("toJSONBase64", [
		DirAttr("value", IvyAttrType.Any)
	]));
}


auto optStorageFn(IvyData opts)
{
	import std.algorithm: canFind;

	import webtank.ivy.opt_set: OptSet;

	Interpreter.assure(
		[IvyDataType.AssocArray, IvyDataType.Null].canFind(opts.type),
		"Expected opts assoc array or null!");

	return new OptSet(opts);
}

AsyncResult remoteCallFn(
	Interpreter interp,
	string service,
	string endpoint,
	string method,
	IvyData params
) {
	import std.exception: enforce;
	import std.algorithm: canFind;

	import webtank.ivy.directive.utils: extraxtHeaders, getEndpointURI;
	import webtank.net.std_json_rpc_client: RemoteCallInfo;
	import webtank.ivy.rpc_client: remoteCall;

	enforce(
		[IvyDataType.Null, IvyDataType.AssocArray].canFind(params.type),
		"JSON-RPC params field must be object or null");

	IvyData[string] context = interp.getGlobalValue("context").assocArray;

	string[][string] headers = extraxtHeaders(context["forwardHTTPHeaders"]);
	string uri = getEndpointURI(context["endpoints"].assocArray, service, endpoint);

	AsyncResult fResult = new AsyncResult();
	try {
		fResult.resolve(RemoteCallInfo(uri, headers).remoteCall!IvyData(method, params));
	} catch(Exception ex) {
		fResult.reject(ex);
	}
	return fResult;
}

string toJSONBase64Fn(IvyData value)
{
	import std.base64: Base64;

	ubyte[] jsonStr = cast(ubyte[]) value.toJSONString();
	return cast(string) Base64.encode(jsonStr);
}