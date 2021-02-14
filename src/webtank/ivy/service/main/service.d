module webtank.ivy.service.main.service;

import webtank.ivy.service.backend: IvyBackendService;

class IvyMainService: IvyBackendService
{
	import webtank.security.auth.core.controller: AuthCoreController;
	import webtank.security.right.controller: AccessRightController;
	import webtank.security.right.db_source: RightDatabaseSource;
	import webtank.security.right.source_method: getAccessRightList;

	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.input: HTTPInput;
	import webtank.net.http.output: HTTPOutput;
	import webtank.net.server.iface: IWebServer;

	import webtank.ivy.access_rule_factory: IvyAccessRuleFactory;
	import webtank.ivy.service.main.context: MainServiceContext;

public:
	this(string serviceName)
	{
		// Создаем бакэнд сервис, но с локальной аутентификацией
		super(serviceName, new AuthCoreController(this));

		// Устанавливаем локальный источник получения прав
		_rights = new AccessRightController(
			new IvyAccessRuleFactory(this._ivyEngine),
			new RightDatabaseSource(this));

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
