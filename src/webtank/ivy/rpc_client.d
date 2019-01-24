module webtank.ivy.rpc_client;

import webtank.ivy.datctrl;
import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;

import webtank.net.std_json_rpc_client:
	remoteCallA = remoteCall,
	remoteCallWebFormA = remoteCallWebForm,
	RemoteCallInfo, getRemoteCallInfoURI;
import webtank.net.http.context: HTTPContext;
import webtank.net.http.input: HTTPInput;
public import webtank.net.std_json_rpc_client: endpoint;

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
	if( response.type != IvyDataType.AssocArray )
		throw new Exception(`Expected assoc array as JSON-RPC response`);

	if( "error" in response )
	{
		if( response["error"].type != IvyDataType.AssocArray ) {
			throw new Exception(`"error" field in JSON-RPC response must be an object`);
		}
		string errorMsg;
		if( "message" in response["error"] ) {
			errorMsg = response["error"]["message"].type == IvyDataType.String? response["error"]["message"].str: null;
		}

		if( "data" in response["error"] )
		{
			IvyData errorData = response["error"]["data"];
			if(
				"file" in errorData &&
				"line" in errorData &&
				errorData["file"].type == IvyDataType.String &&
				errorData["line"].type == IvyDataType.Integer
			) {
				Exception ex = new Exception(errorMsg, errorData["file"].str, errorData["line"].integer);
				if( "backtrace" in errorData && errorData["backtrace"].type == IvyDataType.Array ) {
					ex.info = new OverridenTraceInfo(errorData["backtrace"].array.map!( (it) => it.str.dup ).array );
				}
				throw ex;
			}
		}

		throw new Exception(errorMsg);
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

/// Выполняет вызов метода rpcMethod по протоколу JSON-RPC с узла requestURI и параметрами jsonParams в формате JSON
/// Возвращает результат выполнения метода, разобранный в формате данных шаблонизатора Ivy
IvyData remoteCall(Result, Address, T...)(Address address, string rpcMethod, auto ref T paramsObj)
	if( is(Result == IvyData) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	auto response = remoteCallA!HTTPInput(address, rpcMethod, paramsObj);

	IvyData ivyJSON = _tryParseResponse(address, response.messageBody);
	_checkIvyJSON_RPCErrors(ivyJSON);

	return ivyJSON["result"].tryExtractLvlContainers();
}

IvyData remoteCallWebForm(Result, Address, T...)(Address address, string HTTPMethod = `GET`, string params = null)
	if( is(Result == IvyData) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	auto response = remoteCallWebFormA!HTTPInput(address, HTTPMethod, params);

	IvyData ivyJSON = _tryParseResponse(address, response.messageBody);
	_checkIvyJSON_RPCErrors(ivyJSON);

	return ivyJSON["result"].tryExtractLvlContainers();
}