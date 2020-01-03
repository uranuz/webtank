module webtank.net.server.iface;

import webtank.net.service.iface: IWebService;

interface IWebServer
{
	void start();
	void stop();

	IWebService service() @property;
}