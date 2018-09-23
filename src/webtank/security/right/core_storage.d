module webtank.security.right.core_storage;

import webtank.security.right.iface.access_rule_factory: IAccessRuleFactory;
import webtank.security.right.iface.access_rule: IAccessRule;

class CoreAccessRuleStorage: IAccessRuleFactory
{
private:
	IAccessRule[string] _rules;

public:
	import std.exception: enforce;
	void join(IAccessRule rule)
	{
		enforce(rule.name.length, `Access rule should have name!`);
		enforce(rule.name !in _rules, `Rule name must be unique!`);
		_rules[rule.name] = rule;
	}

	override IAccessRule get(string name)
	{
		enforce(name in _rules, `No access rule name found with name: ` ~ name);
		return _rules[name];
	}
}
