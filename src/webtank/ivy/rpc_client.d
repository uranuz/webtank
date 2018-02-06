module webtank.ivy.rpc_client;

import webtank.ivy.datctrl;
import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;

import webtank.net.std_json_rpc_client: remoteCallA = remoteCall;
import webtank.net.http.context: HTTPContext;
import webtank.net.http.input: HTTPInput;

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
private void _checkIvyJSON_RPCErrors(ref TDataNode response)
{
	import std.algorithm: map;
	import std.array: array;
	if( response.type != DataNodeType.AssocArray )
		throw new Exception(`Expected assoc array as JSON-RPC response`);

	if( "error" in response )
	{
		if( response["error"].type != DataNodeType.AssocArray ) {
			throw new Exception(`"error" field in JSON-RPC response must be an object`);
		}
		string errorMsg;
		if( "message" in response["error"] ) {
			errorMsg = response["error"]["message"].type == DataNodeType.String? response["error"]["message"].str: null;
		}

		if( "data" in response["error"] )
		{
			TDataNode errorData = response["error"]["data"];
			if(
				"file" in errorData &&
				"line" in errorData &&
				errorData["file"].type == DataNodeType.String &&
				errorData["line"].type == DataNodeType.Integer
			) {
				Exception ex = new Exception(errorMsg, errorData["file"].str, errorData["line"].integer);
				if( "backtrace" in errorData && errorData["backtrace"].type == DataNodeType.Array ) {
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

import std.json: JSONValue;

/// Выполняет вызов метода rpcMethod по протоколу JSON-RPC с узла requestURI и параметрами jsonParams в формате JSON
/// Возвращает результат выполнения метода, разобранный в формате данных шаблонизатора Ivy
TDataNode remoteCall(Result)( string requestURI, string rpcMethod, JSONValue jsonParams = JSONValue.init )
	if( is(Result == TDataNode) )
{
	auto response = remoteCallA!HTTPInput(requestURI, rpcMethod, jsonParams);

	TDataNode ivyJSON = parseIvyJSON(response.messageBody);
	_checkIvyJSON_RPCErrors(ivyJSON);

	return ivyJSON["result"].tryExtractLvlContainers();
}

// Перегрузка remoteCall, которая позволяет передать словарь с HTTP заголовками
TDataNode remoteCall(Result)( string requestURI, string rpcMethod, string[string] headers, JSONValue jsonParams = JSONValue.init )
	if( is(Result == TDataNode) )
{
	auto response = remoteCallA!HTTPInput(requestURI, rpcMethod, headers, jsonParams);

	TDataNode ivyJSON = parseIvyJSON(response.messageBody);
	_checkIvyJSON_RPCErrors(ivyJSON);

	return ivyJSON["result"].tryExtractLvlContainers();
}

import webtank.net.std_json_rpc_client: _getAllowedRequestHeaders;

// Перегрузка remoteCall для удобства, которая позволяет передать HTTP контекст для извлечения заголовков
TDataNode remoteCall(Result)( string requestURI, string rpcMethod, HTTPContext context, JSONValue jsonParams = JSONValue.init )
	if( is(Result == TDataNode) )
{
	assert( context !is null, `HTTP context is null` );
	return remoteCall!TDataNode(requestURI, rpcMethod, _getAllowedRequestHeaders(context), jsonParams);
}

