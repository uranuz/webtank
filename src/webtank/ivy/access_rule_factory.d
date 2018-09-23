module webtank.ivy.access_rule_factory;

import webtank.security.right.iface.access_rule_factory: IAccessRuleFactory;
import webtank.ivy.service_mixin: IIvyServiceMixin;
import webtank.ivy.access_rule: IvyAccessRule;
import webtank.security.right.iface.access_rule: IAccessRule;

class IvyAccessRuleFactory: IAccessRuleFactory
{
public:
	this(IIvyServiceMixin ivyService)
	{
		import std.exception: enforce;
		enforce(ivyService !is null, `Expected non null IvyServiceMixin`);
		_ivyService = ivyService;
	}

	override IAccessRule get(string name) {
		return new IvyAccessRule(_ivyService, name);
	}
private:
	IIvyServiceMixin _ivyService;
}