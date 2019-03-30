module webtank.net.service.iface;

interface IWebService
{
	import webtank.common.loger: Loger;
	import webtank.net.http.handler.iface: ICompositeHTTPHandler;
	import webtank.security.access_control: IAccessController;
	import webtank.security.right.iface.controller: IRightController;
	import std.json: JSONValue;

	string[string] virtualPaths() @property;
	string[string] fileSystemPaths() @property;
	string[string] dbConnStrings() @property;
	JSONValue rawConfig() @property;
	string endpoint(string serviceName, string endpointName = null);
	Loger loger() @property;
	ICompositeHTTPHandler rootRouter() @property;
	IAccessController accessController() @property;
	IRightController rightController() @property;
	void stop();
}