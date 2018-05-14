module webtank.net.service.iface;

import webtank.common.loger: Loger;
import webtank.net.http.handler: ICompositeHTTPHandler;
import webtank.security.access_control: IAccessController;
import webtank.security.right.iface.controller: IRightController;

interface IWebService
{
	string[string] virtualPaths() @property;
	string[string] fileSystemPaths() @property;
	string[string] dbConnStrings() @property;
	string endpoint(string serviceName, string endpointName = `default`);
	Loger loger() @property;
	ICompositeHTTPHandler rootRouter() @property;
	IAccessController accessController() @property;
	IRightController rightController() @property;
}