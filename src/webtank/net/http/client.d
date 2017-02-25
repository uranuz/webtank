module webtank.net.http.client;

import webtank.net.http.input, webtank.net.http.output, webtank.net.uri;

/// Осуществляет блокирующий запрос к удалённому HTTP-серверу
/// На вход нужно передать экземпляр HTTPOutput, где как минимум должны быть заполнены
/// свойства requestURI (или rawRequestURI) и method. Возможно, ещё вы захотите передать 
/// и какое-то сообщение (используя метод write), если, например, используется HTTP метод POST
HTTPInput sendRequestAndWait(HTTPOutput request)
{
	assert( request, `Request is null!!!` );
	
	import std.socket;
	URI requestURI = request.requestURI;
	Socket sock = new TcpSocket( new InternetAddress(requestURI.host, requestURI.port) );
	
	sock.send(request.getRequestString());

	return readHTTPInputFromSocket(sock);
}

/// Более простая для понимания перегрузка метода sendRequestAndWait - "для тех, кто в танке" :)
HTTPInput sendRequestAndWait( string requestURI, string method, string messageBody = null )
{
	HTTPOutput request = new HTTPOutput();
	request.rawRequestURI = requestURI;
	request.method = method;
	request.write(messageBody);
	
	return sendRequestAndWait( request );
}

import std.json;

/// Вспомогательный метод для запросов по протоколу JSON-RPC
/// Нужно задать адрес узла requestURI, название RPC-метода (не HTTP-метода)
/// params - JSON-объект с параметрами, которые будут отправлены HTTP-методом "POST"
/// Вызов блокирующий, т.е. ждёт возврата результата удалённым узлом
HTTPInput sendJSON_RPCRequestAndWait( string requestURI, string rpcMethod, ref JSONValue params )
{
	JSONValue payload;
	payload["jsonrpc"] = "2.0";
	payload["method"] = rpcMethod;
	payload["params"] = params;

	return sendRequestAndWait( requestURI, "POST", payload.toJSON() );
}