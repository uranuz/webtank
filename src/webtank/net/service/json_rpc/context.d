module webtank.net.service.json_rpc.context;

import webtank.net.http.context: HTTPContext;

class JSON_RPCServiceContext: HTTPContext
{
	import webtank.net.http.input: HTTPInput;
	import webtank.net.http.output: HTTPOutput;
	import webtank.net.server.iface: IWebServer;

	import webtank.net.service.json_rpc.service: JSON_RPCService;

	this(HTTPInput req, HTTPOutput resp, IWebServer srv)
	{
		import std.exception: enforce;
		super(req, resp, srv);
		enforce(this.service !is null, `Expected instance of JSON_RPCService`);
	}
	
	///Экземпляр сервиса, с общими для процесса данными
	override JSON_RPCService service() @property {
		return cast(JSON_RPCService) _server.service;
	}
}