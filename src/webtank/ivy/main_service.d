module webtank.ivy.main_service;

import webtank.net.service.json_rpc_service: JSON_RPCService;
import webtank.ivy.service_mixin: IvyServiceMixin, IIvyServiceMixin;
import webtank.net.http.context: HTTPContext;
import webtank.net.http.input: HTTPInput;
import webtank.net.http.output: HTTPOutput;
import webtank.net.server.iface: IWebServer;

class IvyMainService: JSON_RPCService, IIvyServiceMixin
{
	import webtank.ivy.access_rule_factory: IvyAccessRuleFactory;
	import webtank.security.auth.core.controller: AuthCoreController;
	import webtank.security.right.controller: AccessRightController;
	import webtank.security.right.db_source: RightDatabaseSource;
	import webtank.security.right.source_method: getAccessRightList;

	mixin IvyServiceMixin;

	this(string serviceName)
	{
		super(serviceName);

		_startIvyLogging();
		_initTemplateCache();

		_rights = new AccessRightController(
			new IvyAccessRuleFactory(this.ivyEngine),
			new RightDatabaseSource(this));
		_accessController = new AuthCoreController(this);

		// Добавляем метод получения прав доступа в состав основного сервиса
		this.JSON_RPCRouter.join!( () =>
			getAccessRightList(rightController.rightSource)
		)(`accessRight.list`);
	}

	override AuthCoreController accessController() @property
	{
		auto controller = cast(AuthCoreController) _accessController;
		assert(controller, `Main service access controller is null`);
		return controller;
	}

	override AccessRightController rightController() @property
	{
		auto controller = cast(AccessRightController) _rights;
		assert(controller, `Main service right controller is null`);
		return controller;
	}

	override MainServiceContext createContext(HTTPInput request, HTTPOutput response, IWebServer server) {
		return new MainServiceContext(request, response, server);
	}
}

// Kind of HTTP-context that exposes details about IvyMainService
class MainServiceContext: HTTPContext
{
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