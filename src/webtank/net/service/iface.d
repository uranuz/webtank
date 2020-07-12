module webtank.net.service.iface;

// Отвечает за получение адресов к удаленным серверам
interface IServiceConfig
{
	import std.json: JSONValue;

	string[string] virtualPaths() @property;
	string[string] fileSystemPaths() @property;
	string[string] dbConnStrings() @property;
	string[string] serviceRoles() @property;
	JSONValue rawConfig() @property;
	string endpoint(string serviceName, string endpointName = null);
}

interface IWebService: IServiceConfig
{
	import webtank.common.loger: Loger;
	import webtank.net.http.handler.iface: ICompositeHTTPHandler;
	import webtank.security.auth.iface.controller: IAuthController;
	import webtank.security.right.iface.controller: IRightController;
	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.input: HTTPInput;
	import webtank.net.http.output: HTTPOutput;
	import webtank.net.server.iface: IWebServer;

	Loger log() @property;
	ICompositeHTTPHandler rootRouter() @property;
	IAuthController accessController() @property;
	IRightController rightController() @property;
	HTTPContext createContext(HTTPInput request, HTTPOutput response, IWebServer server);

	void beforeRunServer();
	void stop();
}