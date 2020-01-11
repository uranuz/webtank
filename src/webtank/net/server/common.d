module webtank.net.server.common;

import std.socket: Socket, SocketShutdown, InternetAddress, SocketOSException;
import core.thread: Thread;
import core.time: dur;
import std.typecons: Tuple;

import webtank.net.http.handler.iface: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.net.http.http: HTTPException;
import webtank.net.http.consts: HTTPStatus, HTTPReasonPhrases;
import webtank.net.http.output: HTTPOutput;
import webtank.net.http.input: HTTPInput, readHTTPInputFromSocket;
import webtank.net.service.iface: IWebService;
import webtank.net.server.iface: IWebServer;

void makeErrorResponse(Throwable error, HTTPOutput response)
{
	import std.conv: text;
	import std.algorithm: castSwitch;

	import webtank.net.utils: makeErrorMsg;
	import webtank.net.utils: parseContentType;

	import webtank.net.http.headers.consts: HTTPHeader;

	auto headers = response.headers;

	auto contentTypeParts = parseContentType(headers.get(HTTPHeader.ContentType, null));

	ushort statusCode = cast(ushort) castSwitch!(
		(HTTPException ex) => ex.HTTPStatusCode,
		(Throwable ex) => HTTPStatus.InternalServerError
	)(error);

	headers.statusCode = statusCode;
	headers[HTTPHeader.Connection] = "close";

	

	string messageBody;
	switch(contentTypeParts.mimeType)
	{
		case "application/json":
		{
			import std.json: toJSON, JSONValue, parseJSON, JSONException;
			import webtank.net.utils: errorToJSON;

			JSONValue jErr = [
				"error": errorToJSON(error)
			]; // Variable for workaround
			// Get saved JSON-RPC "id" field from response headers
			try {
				//jErr["id"] = parseJSON(context.junk.get("jsonrpc-id", null));
			} catch(JSONException) {}
			messageBody = jErr.toJSON();
			break;
		}
		case "plain/text":
		{
			messageBody = makeErrorMsg(error).userError;
			break;
		}
		default:
		{
			string reasonPhrase = headers[HTTPHeader.ReasonPhrase];
			// By default print as HTML
			messageBody = `<html><head><title>` ~ statusCode.text ~ ` ` ~ reasonPhrase ~ `</title></head><body>`
				~ `<h3>` ~ statusCode.text ~ ` ` ~ reasonPhrase ~ `</h3>`
				~ `<h4>` ~ makeErrorMsg(error).userError ~ `</h4>`
				~ `<hr/><p style="text-align: right;">webtank.net.server</p>`
				~ `</body></html>`;
			break;
		}
	}

	response.tryClearBody();
	response.write(messageBody);
}

// Реализация приема и обработки запроса из сокета
void processRequest(Socket sock, IWebServer server)
{
	import webtank.net.utils: makeErrorMsg;
	import webtank.net.http.headers.consts: HTTPHeader;
	import std.exception: enforce;

	scope(exit)
	{
		sock.shutdown(SocketShutdown.BOTH);
		Thread.sleep( dur!("msecs")(30) );
		sock.close();
	}

	HTTPOutput response = new HTTPOutput();
	try
	{
		HTTPInput request = readHTTPInputFromSocket(sock);

		if( request is null )
		{
			server.service.loger.crit(`request is null`);
			return;
		}

		auto context = new HTTPContext(request, response, server);

		try {
			//Запуск обработки HTTP-запроса
			server.service.rootRouter.processRequest(context);
		} catch(Exception ex) {
			server.service.loger.error(makeErrorMsg(ex).details);
			makeErrorResponse(ex, response);
		}

		// Наш сервер не поддерживает соединение
		response.headers[HTTPHeader.Connection] = "close";
		enforce(sock.isAlive, `Unable to send response to user because socket is dead`);
		sock.send(response.getString()); //Главное - отправка результата клиенту
	}
	catch(Exception exc)
	{
		server.service.loger.crit(makeErrorMsg(exc).userError); //Хотим знать, что случилось
		enforce(sock.isAlive, `Unable to send error response to user because socket is dead`);
		makeErrorResponse(exc, response);
		sock.send(response.getString());

		return; // На эксепшоне не падаем - а тихо-мирно завершаемся
	}
	catch(Throwable exc)
	{
		server.service.loger.fatal(makeErrorMsg(exc).userError); //Хотим знать, что случилось
		enforce(sock.isAlive, `Unable to send critical error response to user because socket is dead`);
		makeErrorResponse(exc, response);
		sock.send(response.getString());

		throw exc; // С Throwable не связываемся - и просто роняем Thread
	}
}



void ensureBindSocket(Socket listener, ushort port)
{
	import core.thread: Thread;
	import core.time: dur;
	import std.stdio: writeln;
	import std.conv: text;

	bool isBinded = false;
	writeln("Попытка привязать серверный сокет к порту " ~ port.text);
	while( !isBinded ) //Заставляем ОСь дать нам порт
	{
		try
		{
			InternetAddress addr = new InternetAddress(InternetAddress.ADDR_ANY, port);
			listener.bind(addr);
			isBinded = true;

			//Ждём, чтобы излишне не загружать систему
			Thread.sleep( dur!("msecs")(500) );
		} catch(SocketOSException) {}
	}
	listener.listen(1);
	writeln("Сервер запущен!");
}