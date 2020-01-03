module webtank.net.service.iface;

interface IWebService
{
	import webtank.common.loger: Loger;
	import webtank.net.http.handler.iface: ICompositeHTTPHandler;
	import webtank.security.auth.iface.controller: IAuthController;
	import webtank.security.right.iface.controller: IRightController;
	import std.json: JSONValue;

	string[string] virtualPaths() @property;
	string[string] fileSystemPaths() @property;
	string[string] dbConnStrings() @property;
	string[string] serviceDeps() @property;
	JSONValue rawConfig() @property;
	string endpoint(string serviceName, string endpointName = null);
	Loger loger() @property;
	ICompositeHTTPHandler rootRouter() @property;
	IAuthController accessController() @property;
	IRightController rightController() @property;
	void stop();
}