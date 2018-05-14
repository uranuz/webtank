module webtank.net.std_json_rpc_client;

import webtank.net.http.input, webtank.net.http.output, webtank.net.uri, webtank.net.http.client;

import std.json;

struct RemoteCallInfo
{
	string URI;
	string[string] headers;
}

string _getRequestURI(Address)(ref Address addr)
	if( is(Address: string) || is(Address: RemoteCallInfo) )
{
	static if( is( Address: string ) ) {
		return addr;
	} else {
		return addr.URI;
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
		return sendBlocking(_getRequestURI(addr), "POST", addr.headers, payloadStr);
	} else {
		return sendBlocking(_getRequestURI(addr), "POST", payloadStr);
	}
}

/// Проверяем, если произошла ошибка во время вызова и бросаем исключение, если так
private void _checkJSON_RPCErrors(ref JSONValue response)
{
	if( response.type != JSON_TYPE.OBJECT )
		throw new Exception(`Expected assoc array as JSON-RPC response`);
	
	if( "error" in response )
	{
		if( response["error"].type != JSON_TYPE.OBJECT ) {
			throw new Exception(`"error" field in JSON-RPC response must be an object`);
		}
		string errorMsg;
		if( "message" in response["error"] ) {
			errorMsg = response["error"]["message"].type == JSON_TYPE.STRING? response["error"]["message"].str: null;
		}

		if( "data" in response["error"] )
		{
			JSONValue errorData = response["error"]["data"];
			if(
				"file" in errorData &&
				"line" in errorData &&
				errorData["file"].type == JSON_TYPE.STRING &&
				errorData["line"].type == JSON_TYPE.UINTEGER
			) {
				throw new Exception(errorMsg, errorData["file"].str, errorData["line"].uinteger);
			}
		}

		throw new Exception(errorMsg);
	}

	if( "result" !in response )
		throw new Exception(`Expected "result" field in JSON-RPC response`);
}

/// Перегрузка метода, c возможностью передать HTTP заголовки запроса
JSONValue remoteCall(Result, Address, T...)(Address addr, string rpcMethod, auto ref T paramsObj)
	if( is(Result == JSONValue) && T.length <= 1 && (is(Address: string) || is(Address: RemoteCallInfo)) )
{
	auto response = remoteCall!HTTPInput(addr, rpcMethod, paramsObj);

	try {
		JSONValue bodyJSON = response.messageBody.parseJSON();
		_checkJSON_RPCErrors(bodyJSON); // Проверяем на ошибки

		return bodyJSON["result"];
	} catch (JSONException ex) {
		throw new JSONException("Unable to parse json response:\"" ~ response.messageBody);
	}
}

import webtank.net.http.context: HTTPContext;
private static immutable _allowedHeaders = [
	`user-agent`, `cookie`, `x-real-ip`, `x-forwarded-for`, `x-forwarded-proto`, `x-forwarded-host`, `x-forwarded-port`
];
/// Извлекает разрешенные HTTP заголовки из запроса
string[string] _getAllowedRequestHeaders(HTTPContext ctx)
{
	auto headers = ctx.request.headers;

	string[string] result;
	foreach( name; _allowedHeaders )
	{
		if( name in headers ) {
			result[name] = headers[name];
		}
	}

	return result;
}

/++
Как может создаваться RemoteCallInfo?
	1. Есть просто адрес для вызова (и опционально HTTP-заголовки)
	2. Есть имя удалённого сервиса, экземпляр текущего сервиса (содержащий конфиг) и заголовки
	3. Есть HTTP-контекст текущего вызова и имя удалённого сервиса (и опционально заголовки)
+/

RemoteCallInfo endpoint(HTTPContext ctx, string serviceName, string endpointName = `default`)
{
	return RemoteCallInfo(
		ctx.service.endpoint(serviceName, endpointName),
		_getAllowedRequestHeaders(ctx)
	);
}



