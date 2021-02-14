module webtank.net.http.client;

import webtank.net.http.input: HTTPInput, readHTTPInputFromSocket;
import webtank.net.http.output: HTTPOutput;
import webtank.net.uri: URI;

/// Осуществляет блокирующий запрос к удалённому HTTP-серверу
/// На вход нужно передать экземпляр HTTPOutput, где как минимум должны быть заполнены
/// свойства requestURI (или rawRequestURI) и method. Возможно, ещё вы захотите передать 
/// и какое-то сообщение (используя метод write), если, например, используется HTTP метод POST
HTTPInput remoteRequest(HTTPOutput request)
{
	import std.socket: Socket, TcpSocket, InternetAddress;
	import std.exception: enforce;
	enforce(request, `Request is null!!!`);

	URI requestURI = request.requestURI;
	enforce(requestURI.scheme.length > 0, `Request scheme is not set!`);
	enforce(requestURI.host.length > 3, `Request hostname is invalid!`);
	enforce(requestURI.port != 0, `Request port is not set!`);

	Socket sock = new TcpSocket( new InternetAddress(requestURI.host, requestURI.port) );

	enforce(sock.isAlive, `Unable to send request because socket is dead`);
	sock.send(request.getString());

	return readHTTPInputFromSocket(sock);
}

/// Более простая для понимания перегрузка метода remoteRequest - "для тех, кто в танке" :)
HTTPInput remoteRequest(string requestURI, string method, string messageBody = null)
{
	HTTPOutput request = new HTTPOutput();
	request.rawRequestURI = requestURI;
	request.method = method;
	request.put(messageBody);
	
	return remoteRequest( request );
}

/// Перегрузка метода с возможностью передать словарь с HTTP-заголовками
HTTPInput remoteRequest(string requestURI, string method, string[string] headers, string messageBody = null) {
	return _remoteRequestImpl(requestURI, method, headers, messageBody);
}

HTTPInput remoteRequest(string requestURI, string method, string[][string] headers, string messageBody = null) {
	return _remoteRequestImpl(requestURI, method, headers, messageBody);
}

private HTTPInput _remoteRequestImpl(Headers)(
	string requestURI,
	string method,
	Headers headers,
	string messageBody = null
) {
	HTTPOutput request = new HTTPOutput();
	request.rawRequestURI = requestURI;
	request.method = method;
	request.put(messageBody);

	foreach( key, value; headers ) {
		request.headers[key] = value;
	}

	return remoteRequest( request );
}