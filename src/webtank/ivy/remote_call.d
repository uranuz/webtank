module webtank.ivy.remote_call;

import ivy.interpreter.data_node: IvyDataType, IvyNodeRange, IvyData;
import ivy.interpreter.iface: INativeDirectiveInterpreter;
import ivy.interpreter.interpreter: Interpreter;
import webtank.net.std_json_rpc_client: RemoteCallInfo;
import webtank.ivy.rpc_client: remoteCallWebForm;
import ivy.directive_stuff: DirAttrKind, DirAttrsBlock, DirValueAttr;
import ivy.interpreter.directive: BaseNativeDirInterpreterImpl;
import ivy.interpreter.async_result: AsyncResult;

class RemoteCallInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.algorithm: canFind;
		import std.algorithm: map;
		import std.exception: enforce;
		
		IvyData uriNode = interp.getValue("uri");
		IvyData methodNode = interp.getValue("method");
		IvyData dataNode = interp.getValue("data");
		interp.loger.internalAssert(uriNode.type == IvyDataType.String, `Expected string as URI parameter`);
		interp.loger.internalAssert(
			[IvyDataType.String, IvyDataType.Undef, IvyDataType.Null].canFind(methodNode.type),
			`Expected string as HTTP-method parameter`);
		interp.loger.internalAssert(
			[IvyDataType.String, IvyDataType.Undef, IvyDataType.Null].canFind(dataNode.type),
			`Expected string as data parameter`);

		IvyData forwardHTTPHeadersNode = interp.getValue("forwardHTTPHeaders");
		interp.loger.internalAssert(
			[IvyDataType.AssocArray, IvyDataType.Undef, IvyDataType.Null].canFind(forwardHTTPHeadersNode.type),
			`Expected assoc array as forwardHTTPHeaders global variable`);

		string[string] headers;
		if( forwardHTTPHeadersNode.type == IvyDataType.AssocArray )
		foreach( name, valNode; forwardHTTPHeadersNode.assocArray )
		{
			enforce(valNode.type == IvyDataType.String, `HTTP header value expected to be string`);
			headers[name] = valNode.str;
		}

		AsyncResult fResult = new AsyncResult();
		try
		{
			IvyData methodRes = remoteCallWebForm!IvyData(
				RemoteCallInfo(uriNode.str, headers),
				(methodNode.type == IvyDataType.String? methodNode.str: null),
				(dataNode.type == IvyDataType.String? dataNode.str: null)
			);
			fResult.resolve(methodRes);
		}
		catch(Exception ex)
		{
			fResult.reject(IvyData(ex.msg));
		}
		interp._stack ~= IvyData(fResult);
	}

	private __gshared DirAttrsBlock[] _attrBlocks;
	shared static this()
	{
		_attrBlocks = [
			DirAttrsBlock( DirAttrKind.NamedAttr, [
				`uri`: DirValueAttr("uri", "any"),
				`method`: DirValueAttr("method", "any"),
				`data`: DirValueAttr("data", "any")
			]),
			DirAttrsBlock(DirAttrKind.BodyAttr)
		];
	}

	mixin BaseNativeDirInterpreterImpl!("remoteCall");
}