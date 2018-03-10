module webtank.net.std_json_rpc_client;

import webtank.net.http.input, webtank.net.http.output, webtank.net.uri, webtank.net.http.client;
import webtank.net.service.endpoint: EndPoint;

import std.json;

string _getRequestURI(Address)(Address addr)
	if( is( Address == string ) || is( Address == EndPoint ) )
{
	static if( is( Address == string ) ) {
		return addr;
	} else {
		return addr.URI;
	}
}

/// Вспомогательный метод для запросов по протоколу JSON-RPC
/// Нужно задать адрес узла addr, название RPC-метода (не HTTP-метода)
/// params - JSON-объект с параметрами, которые будут отправлены HTTP-методом "POST"
/// Вызов блокирующий, т.е. ждёт возврата результата удалённым узлом
HTTPInput remoteCall(Result, Address)( Address addr, string rpcMethod, JSONValue params = JSONValue.init )
	if( is(Result: HTTPInput) )
{
	JSONValue payload;
	payload["jsonrpc"] = "2.0";
	payload["method"] = rpcMethod;
	payload["params"] = params;

	// Будем выводить NaN, -Infinity и Infinity в виде строк, чтобы не падать на стороне отправителя данных
	// Если приёмная сторона "захочет", то может распарсить, либо "упасть"
	return sendBlocking( _getRequestURI(addr), "POST", payload.toJSON(false, JSONOptions.specialFloatLiterals) );
}

/// Перегрузка метода с возможностью передать словарь с HTTP-заголовками
HTTPInput remoteCall(Result, Address)( Address addr, string rpcMethod, string[string] headers, JSONValue params = JSONValue.init )
	if( is(Result: HTTPInput) )
{
	JSONValue payload;
	payload["jsonrpc"] = "2.0";
	payload["method"] = rpcMethod;
	payload["params"] = params;

	return sendBlocking( _getRequestURI(addr), "POST", headers, payload.toJSON(false, JSONOptions.specialFloatLiterals) );
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

/// Перегрузка метода, которая возвращает результат в формате std.json
JSONValue remoteCall(Result, Address)( Address addr, string rpcMethod, JSONValue params = JSONValue.init )
	if( is(Result == JSONValue) )
{
	auto response = remoteCall!HTTPInput(_getRequestURI(addr), rpcMethod, params);

	try {
		JSONValue bodyJSON = response.messageBody.parseJSON();
		_checkJSON_RPCErrors(bodyJSON); // Проверяем на ошибки

		return bodyJSON["result"];
	} catch (JSONException ex) {
		throw new JSONException("Unable to parse json response:\"" ~ response.messageBody);
	}
}

/// Перегрузка метода, c возможностью передать HTTP заголовки запроса
JSONValue remoteCall(Result, Address)( Address addr, string rpcMethod, string[string] headers, JSONValue params = JSONValue.init )
	if( is(Result == JSONValue) )
{
	auto response = remoteCall!HTTPInput(_getRequestURI(addr), rpcMethod, headers, params);

	try {
		JSONValue bodyJSON = response.messageBody.parseJSON();
		_checkJSON_RPCErrors(bodyJSON); // Проверяем на ошибки

		return bodyJSON["result"];
	} catch (JSONException ex) {
		throw new JSONException("Unable to parse json response:\"" ~ response.messageBody);
	}
}


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

import webtank.net.http.context;

/// Перегрузка метода с возможностью передачи контекста
JSONValue remoteCall(Result, Address)( Address addr, string rpcMethod, HTTPContext context, JSONValue params = JSONValue.init )
	if( is(Result == JSONValue) )
{
	assert( context !is null, `HTTP context is null` );
	return remoteCall!JSONValue(_getRequestURI(addr), rpcMethod, _getAllowedRequestHeaders(context), params);
}