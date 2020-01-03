module webtank.net.std_json_rpc_client;

import webtank.net.http.input;
import webtank.net.http.output;
import webtank.net.uri;
import webtank.net.http.client;

import std.json;

struct RemoteCallInfo
{
	string URI;
	string[string] headers;
}

struct JSON_RPC_CallResult
{
	JSONValue result;
	HTTPInput response;
}

string getRemoteCallInfoURI(Address)(Address addr)
	if( is(Address: string) || is(Address: RemoteCallInfo) )
{
	static if( is(Address: RemoteCallInfo) ) {
		return addr.URI;
	} else {
		return addr;
	}
}

/// Вспомогательный метод для запросов по протоколу JSON-RPC
/// Нужно задать адрес узла addr, название RPC-метода (не HTTP-метода)
/// params - JSON-объект с параметрами, которые будут отправлены HTTP-методом "POST"
/// Вызов блокирующий, т.е. ждёт возврата результата удалённым узлом
HTTPInput remoteCall(Result, Address, T...)(Address addr, string rpcMethod, auto ref T paramsObj)
	if( is(Result: HTTPInput) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	import webtank.common.std_json.to: toStdJSON;
	JSONValue payload = [
		"jsonrpc": "2.0",
		"method": rpcMethod
	];
	static if( T.length == 0 ) {
		payload["params"] = null;
	} else {
		payload["params"] = toStdJSON(paramsObj[0]);
	}

	string payloadStr = payload.toJSON(false, JSONOptions.specialFloatLiterals);
	static if( is(Address: RemoteCallInfo) ) {
		return sendBlocking(addr.URI, "POST", addr.headers, payloadStr);
	} else {
		return sendBlocking(addr, "POST", payloadStr);
	}
}

JSON_RPC_CallResult remoteCall(Result, Address, T...)(Address addr, string rpcMethod, auto ref T paramsObj)
	if( is(Result: JSON_RPC_CallResult) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	HTTPInput response = remoteCall!HTTPInput(addr, rpcMethod, paramsObj);
	
	JSON_RPC_CallResult res;
	JSONValue bodyJSON;
	try {
		bodyJSON = response.messageBody.parseJSON();
	}
	catch (JSONException ex)
	{
		throw new JSONException(
			"Unable to parse JSON response of remote method \"" ~ rpcMethod 
			~ "\" from service " ~ addr.getRemoteCallInfoURI() ~ ":\n" ~ response.messageBody);
	}

	_checkJSON_RPCErrors(bodyJSON); // Проверяем на ошибки
	res.result = bodyJSON["result"];
	return res;
}

// Перегрузка возвращает только result в виде JSONValue
JSONValue remoteCall(Result, Address, T...)(Address addr, string rpcMethod, auto ref T paramsObj)
	if( is(Result == JSONValue) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	return remoteCall!JSON_RPC_CallResult(addr, rpcMethod, paramsObj).result;
}

/// Проверяем, если произошла ошибка во время вызова и бросаем исключение, если так
private void _checkJSON_RPCErrors(ref JSONValue response)
{
	if( response.type != JSONType.object )
		throw new Exception(`Expected assoc array as JSON-RPC response`);
	
	if( "error" in response )
	{
		if( response["error"].type != JSONType.object ) {
			throw new Exception(`"error" field in JSON-RPC response must be an object`);
		}
		string errorMsg;
		if( "message" in response["error"] ) {
			errorMsg = response["error"]["message"].type == JSONType.string? response["error"]["message"].str: null;
		}

		if( "data" in response["error"] )
		{
			JSONValue errorData = response["error"]["data"];
			if(
				"file" in errorData &&
				"line" in errorData &&
				errorData["file"].type == JSONType.string &&
				errorData["line"].type == JSONType.uinteger
			) {
				throw new Exception(errorMsg, errorData["file"].str, errorData["line"].uinteger);
			}
		}

		throw new Exception(errorMsg);
	}

	if( "result" !in response )
		throw new Exception(`Expected "result" field in JSON-RPC response`);
}



import webtank.net.http.context: HTTPContext;
private static immutable _allowedHeaders = [
	`host`,
	`user-agent`,
	`accept`,
	`accept-language`,
	`connection`,
	`forwarded`,
	`x-real-ip`,
	`x-forwarded-for`,
	`x-forwarded-proto`,
	`x-forwarded-host`,
	`x-forwarded-port`
];
/// Извлекает разрешенные HTTP заголовки из запроса
string[string] getAllowedRequestHeaders(HTTPContext ctx)
{
	auto headers = ctx.request.headers;

	string[string] result;
	foreach( name; _allowedHeaders )
	{
		if( name in headers ) {
			result[name] = headers[name];
		}
	}
	
	// Если мы руками записали что-то в Cookie, то новое значение отличается от заголовков.
	// В связи с этим берем значение заголовка `Cookie` из CookieCollection, а не из заголовков
	// TODO: Сделать, чтобы при обновлении Cookie значение попадало в заголовки автоматом, или по-другому решить проблему
	result[`cookie`] = ctx.request.cookies.toOneLineString();

	return result;
}

/++
Как может создаваться RemoteCallInfo?
	1. Есть просто адрес для вызова (и опционально HTTP-заголовки)
	2. Есть имя удалённого сервиса, экземпляр текущего сервиса (содержащий конфиг) и заголовки
	3. Есть HTTP-контекст текущего вызова и имя удалённого сервиса (и опционально заголовки)
+/

RemoteCallInfo endpoint(HTTPContext ctx, string serviceName, string endpointName = null)
{
	return RemoteCallInfo(
		ctx.service.endpoint(serviceName, endpointName),
		getAllowedRequestHeaders(ctx)
	);
}