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

/// Более простая для понимания перегрузка метода sendBlocking - "для тех, кто в танке" :)
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