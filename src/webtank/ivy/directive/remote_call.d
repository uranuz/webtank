module webtank.ivy.directive.remote_call;

import ivy.interpreter.directive.utils;

class RemoteCallInterpreter: BaseDirectiveInterpreter
{
	import ivy.types.data.async_result: AsyncResult;

	import webtank.net.std_json_rpc_client: RemoteCallInfo;
	import webtank.ivy.rpc_client: remoteCallWebForm;

	this()
	{
		_symbol = new DirectiveSymbol(`remoteCall`, [
			DirAttr("uri", IvyAttrType.Any),
			DirAttr("method", IvyAttrType.Any),
			DirAttr("data", IvyAttrType.Any)
		]);
	}
	
	override void interpret(Interpreter interp)
	{
		import std.algorithm: canFind;
		import std.algorithm: map;
		import std.exception: enforce;
		import std.array: array;
		
		IvyData uriNode = interp.getValue("uri");
		IvyData methodNode = interp.getValue("method");
		IvyData dataNode = interp.getValue("data");
		interp.log.internalAssert(
			uriNode.type == IvyDataType.String,
			`Expected string as URI parameter`);
		interp.log.internalAssert(
			[IvyDataType.String, IvyDataType.Undef, IvyDataType.Null].canFind(methodNode.type),
			`Expected string as HTTP-method parameter`);
		interp.log.internalAssert(
			[IvyDataType.String, IvyDataType.Undef, IvyDataType.Null].canFind(dataNode.type),
			`Expected string as data parameter`);

		IvyData forwardHTTPHeadersNode = interp.getValue("forwardHTTPHeaders");
		interp.log.internalAssert(
			[IvyDataType.AssocArray, IvyDataType.Undef, IvyDataType.Null].canFind(forwardHTTPHeadersNode.type),
			`Expected assoc array as forwardHTTPHeaders global variable`);

		string[][string] headers;
		if( forwardHTTPHeadersNode.type == IvyDataType.AssocArray )
		foreach( name, valNode; forwardHTTPHeadersNode.assocArray )
		{
			enforce(valNode.type == IvyDataType.Array, `HTTP header values list expected to be array`);
			headers[name] = valNode.array.map!( (it) {
				enforce(it.type == IvyDataType.String, `HTTP header value expected to be string`);
				return it.str;
			}).array;
		}

		AsyncResult fResult = new AsyncResult();
		try
		{
			IvyData methodRes = RemoteCallInfo(uriNode.str, headers)
				.remoteCallWebForm!IvyData(
					(methodNode.type == IvyDataType.String? methodNode.str: null),
					(dataNode.type == IvyDataType.String? dataNode.str: null));
			fResult.resolve(methodRes);
		} catch(Exception ex) {
			fResult.reject(ex);
		}
		interp._stack.push(fResult);
	}
}