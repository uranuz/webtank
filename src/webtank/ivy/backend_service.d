module webtank.ivy.backend_service;

import webtank.net.service.json_rpc_service: JSON_RPCService;
import webtank.ivy.service_mixin: IvyServiceMixin, IIvyServiceMixin;
import webtank.ivy.access_rule_factory: IvyAccessRuleFactory;

class IvyBackendService: JSON_RPCService, IIvyServiceMixin
{
	import webtank.security.auth.client.controller: AuthClientController;
	import webtank.security.right.controller: AccessRightController;
	import webtank.security.right.remote_source: RightRemoteSource;
	import webtank.ivy.access_rule_factory: IvyAccessRuleFactory;
	import webtank.net.service.consts: ServiceRole;

	import std.exception: enforce;

	mixin IvyServiceMixin;

	this(string serviceName)
	{
		super(serviceName);

		_startIvyLogging();
		_initTemplateCache();

		_rights = new AccessRightController(
			new IvyAccessRuleFactory(this.ivyEngine),
			new RightRemoteSource(this, ServiceRole.auth, `accessRight.list`));
		_accessController = new AuthClientController(this);
	}

	override AccessRightController rightController() @property
	{
		auto rc = cast(AccessRightController) _rights;
		enforce(rc !is null, `Expected instance of AccessRightController`);
		return rc;
	}

	override AuthClientController accessController() @property
	{
		auto ac = cast(AuthClientController) _accessController;
		enforce(ac !is null, `Expected instance of AuthClientController`);
		return ac;
	}
}