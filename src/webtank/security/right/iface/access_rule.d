module webtank.security.right.iface.access_rule;

interface IAccessRule
{
	string name() @property;

	import webtank.security.access_control: IUserIdentity;
	bool isAllowed(IUserIdentity identity, string[string] data = null);

	string toString();

	import std.json: JSONValue;
	JSONValue toStdJSON();
}
