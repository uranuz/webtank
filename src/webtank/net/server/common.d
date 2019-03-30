module webtank.net.server.common;

import std.socket: Socket, SocketShutdown, InternetAddress, SocketOSException;
import core.thread: Thread;
import core.time: dur;
import webtank.net.http.handler.iface: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.net.http.http: HTTPReasonPhrases, HTTPException;
import webtank.net.http.output: HTTPOutput;
import webtank.net.http.input: HTTPInput, readHTTPInputFromSocket;
import webtank.net.service.iface: IWebService;
import webtank.net.server.iface: IWebServer;

void makeErrorResponse(Throwable ex, HTTPOutput response)
{
	import std.algorithm: castSwitch;
	import std.conv: text;
	import webtank.net.utils: parseContentType;

	string statusCode;
	string reasonPhrase;
	castSwitch!(
		(HTTPException e)
		{
			statusCode = text(e.HTTPStatusCode);
			reasonPhrase = HTTPReasonPhrases.get(e.HTTPStatusCode, "Absolutely unknown status");
		},
		(Throwable e)
		{
			statusCode = "500";
			reasonPhrase = HTTPReasonPhrases.get(500, null);
		},
		() {}
	)(ex);

	auto contentTypeParts = parseContentType(response.headers.get("content-type", null));

	response.headers["status-code"] = statusCode;
	response.headers["reason-phrase"] = reasonPhrase;
	response.headers["connection"] = "close";
	response.tryClearBody();
	response.write(
		errorResponseData(
			ex, contentTypeParts.mimeType, statusCode, reasonPhrase));
}

string errorResponseData(Throwable ex, string mimeType, string statusCode, string reasonPhrase)
{
	import std.json: toJSON, JSONValue;
	import webtank.net.utils: errorToJSON;
	import webtank.net.utils: makeErrorMsg;

	switch(mimeType)
	{
		case "application/json": {
			JSONValue jErr = [
				"error": errorToJSON(ex)
			]; // Variable for workaround
			return jErr.toJSON();
		}
		case "plain/text": {
			return makeErrorMsg(ex).userError;
		}
		default: break;
	}
	// By default print as HTML
	return `<html><head><title>` ~ statusCode ~ ` ` ~ reasonPhrase ~ `</title></head><body>`
		~ `<h3>` ~ statusCode ~ ` ` ~ reasonPhrase ~ `</h3>`
		~ `<h4>` ~ makeErrorMsg(ex).userError ~ `</h4>`
		~ `<hr><p style="text-align: right;">webtank.net.server</p>`
		~ `</body></html>`;
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
			listener.bind(new InternetAddress(port));
			isBinded = true;

			//Ждём, чтобы излишне не загружать систему
			Thread.sleep( dur!("msecs")(500) );
		} catch(SocketOSException) {}
	}
	listener.listen(1);
	writeln("Сервер запущен!");
}