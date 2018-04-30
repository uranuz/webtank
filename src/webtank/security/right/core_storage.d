module webtank.security.right.core_storage;

import webtank.security.right.iface.access_rule: IAccessRule;

class CoreAccessRuleStorage
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

	IAccessRule opIndex(string name)
	{
		enforce(name in _rules, `No access rule name found with name: ` ~ name);
		return _rules[name];
	}

	IAccessRule* opBinaryRight(string op: "in")(string name) {
		return name in _rules;
	}
}
