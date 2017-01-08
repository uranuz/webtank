module webtank.net.http.client;

import webtank.net.http.headers;

// Ответ HTTP сервера клиенту
class ClientResponse
{
private:
	HTTPHeaders _headers;
	public immutable(string) messageBody;

public:
	this( HTTPHeaders headers, string messageBody )
	{
		_headers = headers;
		this.messageBody = messageBody;
	}

	HTTPHeaders headers() @property
	{
		return _headers;
	}

}

// Запрос HTTP клиента серверу
class ClientRequest
{

}

import webtank.net.http.reader;
import std.socket: Socket;

ClientResponse receiveHTTPResponse(Socket sock)
{
	auto receivedData = readHTTPDataFromSocket(sock);

	return new ClientResponse( receivedData.headers, receivedData.messageBody );
}
