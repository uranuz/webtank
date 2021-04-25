module webtank.ivy.rpc_client;

public import webtank.net.std_json_rpc_client: endpoint;

import webtank.common.trace_info: OverridenTraceInfo;
import webtank.net.http.client: remoteRequest;
import webtank.net.std_json_rpc_client:	RemoteCallInfo, getRemoteCallInfoURI;
import webtank.net.http.input: HTTPInput;

import ivy.types.data: IvyData, IvyDataType;
import webtank.ivy.datctrl;

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
	IvyData payload = [
		"jsonrpc": "2.0",
		"method": rpcMethod
	];
	static if( T.length == 0 ) {
		payload["params"] = null;
	} else {
		payload["params"] = paramsObj[0];
	}

	import ivy.types.data.render: renderDataNode2;
	import ivy.types.data.render: DataRenderType;

	IvyRPCCallResult res;
	string payloadStr = renderDataNode2!(DataRenderType.JSON)(payload);
	static if( is(Address: RemoteCallInfo) ) {
		res.response = remoteRequest(address.URI, "POST", address.headers, payloadStr);
	} else {
		res.response = remoteRequest(address, "POST", payloadStr);
	}
	res.result = _parseAndCheckResponse(address, res.response);
	return res;
}

IvyData remoteCall(Result, Address, T...)(
	Address address,
	string rpcMethod,
	auto ref T paramsObj
)
	if( is(Result == IvyData) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	return remoteCall!IvyRPCCallResult(address, rpcMethod, paramsObj).result;
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
		res.response = remoteRequest(address.URI, HTTPMethod, address.headers, params);
	} else {
		res.response = remoteRequest(address, HTTPMethod, params);
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

// Код проверки результата запроса по протоколу JSON-RPC
// По сути этот код дублирует webtank.net.http.client.std_json_rpc, но с другим типом данных
private void _checkIvyJSON_RPCErrors(ref IvyData response)
{
	import std.exception: enforce;

	enforce(
		response.type == IvyDataType.AssocArray,
		`Expected assoc array as JSON-RPC response`);

	if( auto errorPtr = "error" in response )
		throw parseError(*errorPtr);

	if( "result" !in response )
		throw new Exception(`Expected "result" field in JSON-RPC response`);
}

Exception parseError(IvyData error)
{
	import std.algorithm: map;
	import std.array: array;

	if( error.type != IvyDataType.AssocArray ) {
		return new Exception(`"error" field in JSON-RPC response must be an object`);
	}

	string errorMsg;
	if( auto messagePtr = "message" in error ) {
		errorMsg = (messagePtr.type == IvyDataType.String? messagePtr.str: null);
	}

	auto dataPtr = "data" in error;
	if( dataPtr is null || dataPtr.type != IvyDataType.AssocArray ) {
		return new Exception(errorMsg);
	}

	auto filePtr = "file" in *dataPtr;
	auto linePtr = "line" in *dataPtr;

	Exception ex;
	if(
		filePtr && filePtr.type == IvyDataType.String &&
		linePtr && linePtr.type == IvyDataType.Integer
	) {
		ex = new Exception(errorMsg, filePtr.str, linePtr.integer);
	} else {
		ex = new Exception(errorMsg);
	}

	auto backtracePtr = "backtrace" in *dataPtr;
	if( backtracePtr && backtracePtr.type == IvyDataType.Array ) {
		ex.info = new OverridenTraceInfo((*backtracePtr).array.map!( (it) => it.str.dup ).array);
	}
	return ex;
}

IvyData _tryParseResponse(Address)(Address addr, string messageBody)
{
	import ivy.types.data.conv.json_parser: parseIvyJSON, IvyJSONException;
	
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
