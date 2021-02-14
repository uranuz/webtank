module webtank.ivy.service.main.context;

import webtank.net.service.json_rpc.context: JSON_RPCServiceContext;

// Kind of HTTP-context that exposes details about IvyMainService
class MainServiceContext: JSON_RPCServiceContext
{
	import webtank.net.http.input: HTTPInput;
	import webtank.net.http.output: HTTPOutput;
	import webtank.net.server.iface: IWebServer;

	import webtank.ivy.service.main.service: IvyMainService;

	this(HTTPInput req, HTTPOutput resp, IWebServer srv)
	{
		import std.exception: enforce;
		super(req, resp, srv);
		enforce(this.service !is null, `Expected instance of IvyMainService`);
	}
	
	///Экземпляр сервиса, с общими для процесса данными
	override IvyMainService service() @property {
		return cast(IvyMainService) _server.service;
	}
}