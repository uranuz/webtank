module webtank.net.server.common;

import std.socket: Socket, SocketShutdown, InternetAddress, SocketOSException;
import core.thread: Thread;
import core.time: dur;
import std.typecons: Tuple;

import webtank.net.http.handler.iface: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.net.http.http: HTTPReasonPhrases, HTTPException;
import webtank.net.http.output: HTTPOutput;
import webtank.net.http.input: HTTPInput, readHTTPInputFromSocket;
import webtank.net.service.iface: IWebService;
import webtank.net.server.iface: IWebServer;

void makeErrorResponse(Throwable error, HTTPOutput response)
{
	import std.conv: text;

	import webtank.net.utils: makeErrorMsg;
	import webtank.net.utils: parseContentType;

	auto errHead = getHTTPErrorHeaders(error);
	auto contentTypeParts = parseContentType(response.headers.get("content-type", null));
	string statusCode = text(errHead.statusCode);

	response.headers["status-code"] = statusCode;
	response.headers["reason-phrase"] = errHead.reasonPhrase;
	response.headers["connection"] = "close";

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
				jErr["id"] = parseJSON(response.headers.get("jsonrpc-id", null));
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
			// By default print as HTML
			messageBody = `<html><head><title>` ~ statusCode ~ ` ` ~ errHead.reasonPhrase ~ `</title></head><body>`
				~ `<h3>` ~ statusCode ~ ` ` ~ errHead.reasonPhrase ~ `</h3>`
				~ `<h4>` ~ makeErrorMsg(error).userError ~ `</h4>`
				~ `<hr/><p style="text-align: right;">webtank.net.server</p>`
				~ `</body></html>`;
			break;
		}
	}

	response.tryClearBody();
	response.write(messageBody);
}

Tuple!(
	ushort, `statusCode`,
	string, `reasonPhrase`
)
getHTTPErrorHeaders(Throwable error)
{
	import std.algorithm: castSwitch;

	typeof(return) res;
	res.statusCode = cast(ushort) castSwitch!(
		(HTTPException ex) => ex.HTTPStatusCode,
		(Throwable ex) => 500
	)(error);
	res.reasonPhrase = HTTPReasonPhrases.get(res.statusCode, "Absolutely unknown status");
	return res;
}

// Реализация приема и обработки запроса из сокета
void processRequest(Socket sock, IWebService service, IWebServer server)
{
	import webtank.net.utils: makeErrorMsg;

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
			service.loger.crit(`request is null`);
			return;
		}
		
		auto context = new HTTPContext(request, response, service, server);

		try {
			//Запуск обработки HTTP-запроса
			service.rootRouter.processRequest(context);
		} catch(Exception ex) {
			service.loger.error(makeErrorMsg(ex).details);
			makeErrorResponse(ex, response);
		}

		// Наш сервер не поддерживает соединение
		response.headers["connection"] = "close";
		sock.send(response.getResponseString()); //Главное - отправка результата клиенту
	}
	catch(Exception exc)
	{
		service.loger.crit(makeErrorMsg(exc).userError); //Хотим знать, что случилось
		makeErrorResponse(exc, response);
		sock.send(response.getResponseString());

		return; // На эксепшоне не падаем - а тихо-мирно завершаемся
	}
	catch(Throwable exc)
	{
		service.loger.fatal(makeErrorMsg(exc).userError); //Хотим знать, что случилось
		makeErrorResponse(exc, response);
		sock.send(response.getResponseString());

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