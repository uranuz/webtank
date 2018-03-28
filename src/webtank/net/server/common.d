module webtank.net.server.common;

import webtank.net.http.handler: IHTTPHandler;
import webtank.net.http.context: HTTPContext;
import webtank.net.http.http: HTTPReasonPhrases, HTTPException;
import webtank.net.http.output: HTTPOutput;

HTTPOutput makeErrorResponse(Throwable exc)
{
	import std.algorithm: castSwitch;
	import std.conv: text;

	HTTPOutput response = new HTTPOutput();
	string statusCode;
	string reasonPhrase;
	castSwitch!(
		(HTTPException e)
		{
			statusCode = text( e.HTTPStatusCode );
			reasonPhrase = HTTPReasonPhrases.get(e.HTTPStatusCode, "Absolutely unknown status");
		},
		(Throwable e)
		{
			statusCode = "500";
			reasonPhrase = HTTPReasonPhrases.get(500, null);
		},
		() {}
	)(exc);

	response.headers["status-code"] = statusCode;
	response.headers["reason-phrase"] = reasonPhrase;
	response.headers["connection"] = "close";
	response.write(
		`<html><head><title>` ~ statusCode ~ ` ` ~ reasonPhrase ~ `</title></head><body>`
		~ `<h3>` ~ statusCode ~ ` ` ~ reasonPhrase ~ `</h3>`
		~ `<h4>` ~ exc.msg ~ `</h4>`
		~ `<hr><p style="text-align: right;">webtank.net.server</p>`
		~ `</body></html>`
	);

	return response;
}

string makeErrorMsg( Throwable exc )
{
	import std.conv: to;
	return "Exception occurred in file: " ~ exc.file ~ " (" ~ exc.line.to!string ~ "):\r\n" ~ exc.msg ~ "\r\nTraceback info:\r\n" ~ exc.info.to!string;
}

// Реализация приема и обработки запроса из сокета
mixin template ProcessRequestImpl()
{
	import std.socket: Socket, SocketShutdown;
	import core.thread: Thread;
	import core.time: dur;
	import webtank.net.server.common: makeErrorMsg, makeErrorResponse;
	import webtank.net.http.input: HTTPInput, readHTTPInputFromSocket;
	import webtank.net.http.output: HTTPOutput;

	private void _processRequest(Socket sock)
	{
		scope(exit)
		{
			sock.shutdown(SocketShutdown.BOTH);
			Thread.sleep( dur!("msecs")(30) );
			sock.close();
		}

		try
		{
			HTTPInput request = readHTTPInputFromSocket(sock);

			if( request is null )
			{
				this._loger.crit( `request is null` );
				return;
			}

			auto context = new HTTPContext(request, new HTTPOutput());

			//Запуск обработки HTTP-запроса
			this._handler.processRequest(context);

			//Наш сервер не поддерживает соединение
			context.response.headers["connection"] = "close";
			sock.send( context.response.getResponseString() ); //Главное - отправка результата клиенту
		}
		catch(Exception exc)
		{
			this._loger.crit( makeErrorMsg(exc) ); //Хотим знать, что случилось
			sock.send( makeErrorResponse(exc).getResponseString() );

			return; // На эксепшоне не падаем - а тихо-мирно завершаемся
		}
		catch(Throwable exc)
		{
			this._loger.fatal( makeErrorMsg(exc) ); //Хотим знать, что случилось
			sock.send( makeErrorResponse(exc).getResponseString() );

			throw exc; // С Throwable не связываемся - и просто роняем Thread
		}
	}
}

import std.socket: Socket, InternetAddress, SocketOSException;

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