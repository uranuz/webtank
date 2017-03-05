module webtank.net.http.client;

import webtank.net.http.input, webtank.net.http.output, webtank.net.uri;

/// Осуществляет блокирующий запрос к удалённому HTTP-серверу
/// На вход нужно передать экземпляр HTTPOutput, где как минимум должны быть заполнены
/// свойства requestURI (или rawRequestURI) и method. Возможно, ещё вы захотите передать 
/// и какое-то сообщение (используя метод write), если, например, используется HTTP метод POST
HTTPInput sendBlocking(HTTPOutput request)
{
	assert( request, `Request is null!!!` );
	
	import std.socket;
	URI requestURI = request.requestURI;
	Socket sock = new TcpSocket( new InternetAddress(requestURI.host, requestURI.port) );
	
	sock.send(request.getRequestString());

	return readHTTPInputFromSocket(sock);
}

/// Более простая для понимания перегрузка метода sendRequestAndWait - "для тех, кто в танке" :)
HTTPInput sendBlocking( string requestURI, string method, string messageBody = null )
{
	HTTPOutput request = new HTTPOutput();
	request.rawRequestURI = requestURI;
	request.method = method;
	request.write(messageBody);
	
	return sendBlocking( request );
}

/// Перегрузка метода с возможностью передать словарь с HTTP-заголовками
HTTPInput sendBlocking( string requestURI, string method, string[string] headers, string messageBody = null )
{
	HTTPOutput request = new HTTPOutput();
	request.rawRequestURI = requestURI;
	request.method = method;
	request.write(messageBody);

	foreach( key, value; headers ) {
		request.headers[key] = value;
	}

	return sendBlocking( request );
}

import std.json;

/// Вспомогательный метод для запросов по протоколу JSON-RPC
/// Нужно задать адрес узла requestURI, название RPC-метода (не HTTP-метода)
/// params - JSON-объект с параметрами, которые будут отправлены HTTP-методом "POST"
/// Вызов блокирующий, т.е. ждёт возврата результата удалённым узлом
HTTPInput sendJSON_RPCBlocking(Result)( string requestURI, string rpcMethod, ref JSONValue params )
	if( is(Result: HTTPInput) )
{
	JSONValue payload;
	payload["jsonrpc"] = "2.0";
	payload["method"] = rpcMethod;
	payload["params"] = params;

	return sendBlocking( requestURI, "POST", payload.toJSON() );
}

/// Перегрузка метода с возможностью передать словарь с HTTP-заголовками
HTTPInput sendJSON_RPCBlocking(Result)( string requestURI, string rpcMethod, string[string] headers, ref JSONValue params )
	if( is(Result: HTTPInput) )
{
	JSONValue payload;
	payload["jsonrpc"] = "2.0";
	payload["method"] = rpcMethod;
	payload["params"] = params;

	return sendBlocking( requestURI, "POST", headers, payload.toJSON() );
}

/// Проверяем, если произошла ошибка во время вызова и бросаем исключение, если так
private void _checkJSON_RPCErrors(JSONValue bodyJSON)
{
	if( "error" in bodyJSON )
	{
		string msg = "Unknown JSON-RPC error";

		JSONValue errorObj = bodyJSON["error"];
		if( errorObj.type == JSON_TYPE.OBJECT )
		{
			msg = `JSON-RPC error. `;
			if( "code" in errorObj && (errorObj["code"].type == JSON_TYPE.UINTEGER || errorObj["code"].type == JSON_TYPE.INTEGER) )
			{
				import std.conv: text;
				msg ~= `Code: ` ~ ( errorObj["code"].type == JSON_TYPE.UINTEGER ? errorObj["code"].uinteger.text : errorObj["code"].integer.text ) ~ `.`;
			}

			if( "message" in errorObj && errorObj["message"].type == JSON_TYPE.STRING )
			{
				msg ~= ` Message: "` ~ errorObj["message"].str ~ `".`;
			}
		}

		throw new Exception(msg);
	}
}

/// Перегрузка метода, которая возвращает результат в формате std.json
JSONValue sendJSON_RPCBlocking( string requestURI, string rpcMethod, ref JSONValue jsonParams )
{
	auto response = sendJSON_RPCBlocking!(HTTPInput)(requestURI, rpcMethod, jsonParams);

	JSONValue bodyJSON = response.bodyJSON;
	assert( bodyJSON.type == JSON_TYPE.OBJECT, `Expected object as JSON-RPC result` );

	_checkJSON_RPCErrors(bodyJSON); // Проверяем на ошибки
	assert( "result" in bodyJSON, `Expected "result" field in JSON-RPC result` );

	return bodyJSON["result"];
}

/// Перегрузка метода, c возможностью передать HTTP заголовки запроса
JSONValue sendJSON_RPCBlocking( string requestURI, string rpcMethod, string[string] headers, ref JSONValue jsonParams )
{
	auto response = sendJSON_RPCBlocking!(HTTPInput)(requestURI, rpcMethod, headers, jsonParams);

	JSONValue bodyJSON = response.bodyJSON;
	assert( bodyJSON.type == JSON_TYPE.OBJECT, `Expected object as JSON-RPC result` );

	_checkJSON_RPCErrors(bodyJSON); // Проверяем на ошибки
	assert( "result" in bodyJSON, `Expected "result" field in JSON-RPC result` );

	return bodyJSON["result"];
}