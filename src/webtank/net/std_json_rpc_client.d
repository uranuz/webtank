module webtank.net.std_json_rpc_client;

import webtank.net.http.input;
import webtank.net.http.output;
import webtank.net.uri;
import webtank.net.http.client;

import std.json;

struct RemoteCallInfo
{
	string URI;
	string[][string] headers;
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
	JSON_RPC_CallResult res;
	res.response = remoteCall!HTTPInput(addr, rpcMethod, paramsObj);

	JSONValue bodyJSON;
	try {
		bodyJSON = res.response.messageBody.parseJSON();
	}
	catch (JSONException ex)
	{
		throw new JSONException(
			"Unable to parse JSON response of remote method \"" ~ rpcMethod 
			~ "\" from service " ~ addr.getRemoteCallInfoURI() ~ ":\n" ~ res.response.messageBody);
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

	auto errorPtr = "error" in response;
	if( errorPtr )
	{
		if( errorPtr.type != JSONType.object ) {
			throw new Exception(`"error" field in JSON-RPC response must be an object`);
		}
		string errorMsg;
		if( auto messagePtr = "message" in (*errorPtr) ) {
			errorMsg = messagePtr.type == JSONType.string? messagePtr.str: null;
		}

		auto errorDataPtr = "data" in *errorPtr;
		if( errorDataPtr && errorDataPtr.type == JSONType.object )
		{
			auto errorFilePtr = "file" in *errorDataPtr;
			auto errorLinePtr = "line" in *errorDataPtr;
			if(
				errorFilePtr && errorFilePtr.type == JSONType.string &&
				errorLinePtr && errorLinePtr.type == JSONType.uinteger
			) {
				throw new Exception(errorMsg, errorFilePtr.str, errorLinePtr.uinteger);
			}
		}

		throw new Exception(errorMsg);
	}

	if( "result" !in response )
		throw new Exception(`Expected "result" field in JSON-RPC response`);
}


import webtank.net.http.context: HTTPContext;
import webtank.net.http.input: HTTPInput;
import webtank.net.http.headers.consts: HTTPHeader;
private static immutable _allowedHeaders = [
	HTTPHeader.Accept,
	HTTPHeader.AcceptLanguage,
	HTTPHeader.Connection,
	HTTPHeader.Forwarded,
	HTTPHeader.Host,
	HTTPHeader.XRealIP,
	HTTPHeader.XForwardedFor,
	HTTPHeader.XForwardedProto,
	HTTPHeader.XForwardedHost,
	HTTPHeader.XForwardedPort,
	HTTPHeader.UserAgent,
	HTTPHeader.Cookie,
	HTTPHeader.SetCookie
];
/// Извлекает разрешенные HTTP заголовки из запроса
string[][string] getAllowedRequestHeaders(HTTPInput request)
{
	auto headers = request.headers;

	string[][string] result;
	foreach( name; _allowedHeaders )
	{
		string[] headerArr = headers.array(name);
		if( headerArr.length > 0 ) {
			result[name] = headerArr;
		}
	}

	return result;
}

string[][string] getAllowedRequestHeaders(HTTPContext ctx) {
	return ctx.request.getAllowedRequestHeaders();
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