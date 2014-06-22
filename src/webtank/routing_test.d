module webtank.routing_test;

import webtank.net.http.handler, webtank.net.http.context, webtank.net.http.json_rpc_handler, webtank.net.web_server, webtank.net.access_control, webtank.net.uri_pattern;

import mkk_site.access_control, mkk_site.site_data;

import std.stdio, std.getopt, std.conv;

__gshared HTTPRouter router;
__gshared URIPageRouter pageRouter;
__gshared JSON_RPC_Router jsonRPCRouter;

shared static this()
{	router = new HTTPRouter;
	pageRouter = new URIPageRouter( "/dyn/{remainder}" );
	jsonRPCRouter = new JSON_RPC_Router( "/dyn/jsonrpc/{remainder}" );
	
	router
		.join(pageRouter)
		.join(jsonRPCRouter);
		
	router.onError ~= (HTTPContext context, Throwable error) {
		context.response ~= "<http><body><h2>500 Внутренняя ошибка сервера!!!</h2>\r\n" 
		~ error.to!string ~ "</body></http>";
		return true;
	};
	
	auto ticketManager = new MKK_SiteuserManager(authDBConnStr);
	
	router.onPreProcess ~= (HTTPContext context) {
		context._setuser( ticketManager.getTicket(context) );
	};
	
	jsonRPCRouter.join!(rpcFunc);
	pageRouter.join!(netMain)("/dyn/vasya");
	
	jsonRPCRouter.onError ~= (HTTPContext context, Throwable error) {
		context.response ~= `{"jsonrpc":"2.0","error":{"msg":"` 
		~ error.msg ~ `"}}`;
		return true;
	};
}

string rpcFunc(HTTPContext context, string[string] assocList, int shit)
{	writeln( "context is null: ", context is null );
	writeln( "context.user is null: ", context.user is null );
	writeln( "context.user is null: ", context.user is null );
	writeln("user.login: ", context.user.id);
	writeln("Hello, router!!!");
	return "Your kesha is " ~ assocList.get("kesha", null);
	
}

void netMain(HTTPContext context)
{	context.response ~= "Hello, World, again!!!";
	//writeln("Hello, ", context.user.isAuthenticated);
	
}


void main(string[] progAgs) {
	//Основной поток - поток управления потоками

	ushort port = 8082;
	//Получаем порт из параметров командной строки
	getopt( progAgs, "port", &port );

	
	auto server = new WebServer(port, router);
	server.start();
}