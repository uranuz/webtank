module mkk_site.xhr_test;

import std.conv, std.string, std.file, std.stdio;

import webtank.net.http.context, webtank.net.http.json_rpc_routing, webtank.net.http.routing, mkk_site.site_data, mkk_site.utils;

immutable thisPagePath = dynamicPath ~ "edit_tourist";
immutable authPagePath = dynamicPath ~ "auth";

shared static this()
{	Router.join( new URIHandlingRule(thisPagePath, &netMain) );
	Router.join( new JSON_RPC_HandlingRule!(приветствие) );
}

string приветствие(string имя)
{	return `Привет, ` ~ имя ~ `!!!`;
}

void netMain(HTTPContext context)
{	auto rq = context.request;
	auto rp = context.response;
	auto ticket = context.user;
	
	auto pVars = context.request.bodyForm;
	auto qVars = context.request.queryForm;
	
	auto tpl = getPageTemplate( pageTemplatesDir ~ "dyn_request_test.html" );
	
	rp ~= tpl.getString();
}

// string Выполнить(string arg, double arg2)
// {	return ( "ЗАРАБОТАЛО!!! - " ~ arg.to!string ~ arg2.to!string );
// // 	return 100 + arg2;
// }