module webtank.security.right.plain_rule;

import webtank.security.right.iface.access_rule: IAccessRule;
import webtank.security.access_control: IUserIdentity;

alias AccessRuleDelType = bool delegate(IUserIdentity identity, string[string] data);

class PlainAccessRule: IAccessRule
{
private:
	string _name;
	AccessRuleDelType _del;

public:
	this(string name, AccessRuleDelType deleg)
	{
		_name = name;
		_del = deleg;
	}

	public override {
		string name() @property {
			return _name;
		}

		bool isAllowed(IUserIdentity identity, string[string] data = null)
		{
			if( _del is null ) {
				return false;
			}
			return _del(identity, data);
		}
	}

	override string toString() {
		return `PlainAccessRule: ` ~ _name;
	}

	import std.json: JSONValue;
	override JSONValue toStdJSON()
	{
		return JSONValue([
			"kind": "PlainAccessRule",
			"name": name
		]);
	}
}