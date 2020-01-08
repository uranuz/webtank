module webtank.ivy.rpc_client;

import webtank.ivy.datctrl;
import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;

import webtank.net.http.client: sendBlocking;
import webtank.net.std_json_rpc_client:
	remoteCallA = remoteCall,
	RemoteCallInfo, getRemoteCallInfoURI;
import webtank.net.http.context: HTTPContext;
import webtank.net.http.input: HTTPInput;
public import webtank.net.std_json_rpc_client: endpoint;

struct IvyRPCCallResult
{
	HTTPInput response;
	IvyData result;
}

/// Выполняет вызов метода rpcMethod по протоколу JSON-RPC с узла address и параметрами paramsObj
/// Возвращает результат выполнения метода типа IvyRPCCallResult
IvyRPCCallResult remoteCall(Result, Address, T...)(Address address, string rpcMethod, auto ref T paramsObj)
	if( is(Result == IvyRPCCallResult) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	IvyRPCCallResult res;
	res.response = remoteCallA!HTTPInput(address, rpcMethod, paramsObj);
	res.result = _parseAndCheckResponse(address, res.response);
	return res;
}

IvyData remoteCall(Result, Address, T...)(Address address, string rpcMethod, auto ref T paramsObj)
	if( is(Result == IvyData) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	return remoteCallA!IvyRPCCallResult(address, rpcMethod, paramsObj).result;
}

IvyRPCCallResult remoteCallWebForm(Result, Address)(
	Address address,
	string HTTPMethod,
	string params = null
)
	if( is(Result == IvyRPCCallResult) && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	IvyRPCCallResult res;

	static if( is(Address: RemoteCallInfo) ) {
		res.response = sendBlocking(address.URI, HTTPMethod, address.headers, params);
	} else {
		res.response = sendBlocking(address, HTTPMethod, params);
	}
	
	res.result = _parseAndCheckResponse(address, res.response);
	return res;
}

IvyData remoteCallWebForm(Result, Address)(
	Address address,
	string HTTPMethod,
	string params = null
)
	if( is(Result == IvyData) && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	return remoteCallWebForm!IvyRPCCallResult(address, HTTPMethod, params).result;
}

class OverridenTraceInfo: object.Throwable.TraceInfo
{
	private char[][] _backTrace;
	this(char[][] traceInfo) {
		_backTrace = traceInfo;
	}

	override {
		int opApply(scope int delegate(ref const(char[])) dg) const
		{
			int result = 0;
			foreach( i; 0.._backTrace.length )
			{
				result = dg(_backTrace[i]);
				if (result)
					break;
			}
			return result;
		}
		int opApply(scope int delegate(ref size_t, ref const(char[])) dg) const
		{
			int result = 0;
			foreach( i; 0.._backTrace.length )
			{
				result = dg(i, _backTrace[i]);
				if (result)
					break;
			}
			return result;
		}
		string toString() const
		{
			import std.array: join;
			return cast(string) _backTrace.join('\n');
		}
	}
}

// Код проверки результата запроса по протоколу JSON-RPC
// По сути этот код дублирует webtank.net.http.client.std_json_rpc, но с другим типом данных
private void _checkIvyJSON_RPCErrors(ref IvyData response)
{
	import std.algorithm: map;
	import std.array: array;
	import std.exception: enforce;

	enforce(
		response.type == IvyDataType.AssocArray,
		`Expected assoc array as JSON-RPC response`);

	if( auto errorPtr = "error" in response )
	{
		enforce(
			errorPtr.type == IvyDataType.AssocArray,
			`"error" field in JSON-RPC response must be an object`);

		string errorMsg;
		if( auto messagePtr = "message" in *errorPtr ) {
			errorMsg = messagePtr.type == IvyDataType.String? messagePtr.str: null;
		}

		Exception ex;
		auto errorDataPtr = "data" in *errorPtr;
		if( errorDataPtr && errorDataPtr.type == IvyDataType.String )
		{
			auto errorFilePtr = "file" in *errorDataPtr;
			auto errorLinePtr = "line" in *errorDataPtr;

			if(
				errorFilePtr && errorFilePtr.type == IvyDataType.String &&
				errorLinePtr && errorLinePtr.type == IvyDataType.Integer
			) {
				ex = new Exception(errorMsg, errorFilePtr.str, errorLinePtr.integer);
			}

			auto backtracePtr = "backtrace" in *errorDataPtr;
			if( backtracePtr && backtracePtr.type == IvyDataType.Array ) {
				ex.info = new OverridenTraceInfo(backtracePtr.array.map!( (it) => it.str.dup ).array );
			}
		} else {
			ex = new Exception(errorMsg);
		}

		throw ex;
	}

	if( "result" !in response )
		throw new Exception(`Expected "result" field in JSON-RPC response`);
}

IvyData _tryParseResponse(Address)(Address addr, string messageBody)
{
	IvyData ivyJSON;
	try {
		ivyJSON = parseIvyJSON(messageBody);
	}
	catch (IvyJSONException ex)
	{
		throw new IvyJSONException(
			"Unable to parse Ivy JSON response of from service " ~ addr.getRemoteCallInfoURI() ~ ":\n" ~ messageBody);
	}
	return ivyJSON;
}

IvyData _parseAndCheckResponse(Address)(Address addr, HTTPInput response)
{
	IvyData ivyJSON = _tryParseResponse(addr, response.messageBody);
	_checkIvyJSON_RPCErrors(ivyJSON);

	return ivyJSON["result"].tryExtractLvlContainers();
}
