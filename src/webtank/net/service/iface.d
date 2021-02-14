module webtank.net.service.iface;

interface IWebService
{
	import webtank.net.service.config.iface: IServiceConfig;
	import webtank.common.log.writer: LogWriter;
	import webtank.net.http.handler.iface: ICompositeHTTPHandler;
	import webtank.security.auth.iface.controller: IAuthController;
	import webtank.security.right.iface.controller: IRightController;
	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.input: HTTPInput;
	import webtank.net.http.output: HTTPOutput;
	import webtank.net.server.iface: IWebServer;

	IServiceConfig config() @property;
	LogWriter log() @property;
	ICompositeHTTPHandler rootRouter() @property;
	IAuthController accessController() @property;
	IRightController rightController() @property;
	HTTPContext createContext(HTTPInput request, HTTPOutput response, IWebServer server);

	void beforeRunServer();
	void stop();
}