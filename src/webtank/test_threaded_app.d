module test_threaded_app;

import std.stdio;

import webtank.net.application, webtank.net.http_cookie;

static this()
{	Application.setHandler(&netMain, "/dynamic/vasya");
	Application.setHandler(&netMain, "/dynamic/vasya/");
}

Application netApp;

void netMain(Application netApp)
{	test_threaded_app.netApp = netApp;
	netApp.response ~= "Вася!";
	writeln( netApp.request.messageBody );
}
