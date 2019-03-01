module webtank.ivy.access_rule_factory;

import webtank.security.right.iface.access_rule_factory: IAccessRuleFactory;
import webtank.ivy.access_rule: IvyAccessRule;
import webtank.security.right.iface.access_rule: IAccessRule;
import ivy.engine: IvyEngine;

class IvyAccessRuleFactory: IAccessRuleFactory
{
public:
	this(IvyEngine ivyEngine)
	{
		import std.exception: enforce;
		enforce(ivyEngine, `Expected IvyEngine`);
		_ivyEngine = ivyEngine;
	}

	override IAccessRule get(string name) {
		return new IvyAccessRule(_ivyEngine, name);
	}
private:
	IvyEngine _ivyEngine;
}