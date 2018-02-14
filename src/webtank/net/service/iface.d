module webtank.net.service.iface;

import webtank.common.loger: Loger;
import webtank.net.http.handler: ICompositeHTTPHandler;
import webtank.security.access_control;

interface IWebService
{
	string[string] virtualPaths() @property;
	string[string] fileSystemPaths() @property;
	string[string] dbConnStrings() @property;
	string getEndpointAddress(string serviceName, string endpointName);
	Loger loger() @property;
	ICompositeHTTPHandler rootRouter() @property;
	IAccessController accessController() @property;
}