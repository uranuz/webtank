module webtank.ivy.service.view.context;

import webtank.net.http.context: HTTPContext;

class IvyViewServiceContext: HTTPContext
{
	import webtank.net.http.input: HTTPInput;
	import webtank.net.http.output: HTTPOutput;
	import webtank.net.server.iface: IWebServer;

	import webtank.ivy.service.view: IvyViewService;

	this(HTTPInput req, HTTPOutput resp, IWebServer srv)
	{
		import std.exception: enforce;
		super(req, resp, srv);
		enforce(this.service !is null, `Expected instance of IvyViewService`);
	}
	
	///Экземпляр сервиса, с общими для процесса данными
	override IvyViewService service() @property {
		return cast(IvyViewService) _server.service;
	}
}