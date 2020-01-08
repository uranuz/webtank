module webtank.ivy.main_service;

import webtank.net.service.json_rpc_service: JSON_RPCService;
import webtank.ivy.service_mixin: IvyServiceMixin, IIvyServiceMixin;

import webtank.db.database: IDatabase;

alias GetAuthDBMethod = IDatabase delegate();

class IvyMainService: JSON_RPCService, IIvyServiceMixin
{
	import webtank.ivy.access_rule_factory: IvyAccessRuleFactory;
	import webtank.security.auth.core.controller: AuthCoreController;
	import webtank.security.right.controller: AccessRightController;
	import webtank.security.right.db_source: RightDatabaseSource;
	import webtank.security.right.source_method: getAccessRightList;

	mixin IvyServiceMixin;

	this(string serviceName, GetAuthDBMethod getAuthDB)
	{
		super(serviceName);

		_startIvyLogging();
		_initTemplateCache();

		_rights = new AccessRightController(
			new IvyAccessRuleFactory(this.ivyEngine),
			new RightDatabaseSource(getAuthDB));
		_accessController = new AuthCoreController(getAuthDB);

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
}
