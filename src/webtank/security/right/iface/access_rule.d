module webtank.security.right.iface.access_rule;

interface IAccessRule
{
	string name() @property;

	import webtank.security.access_control: IUserIdentity;
	bool hasRight(IUserIdentity identity, string[string] data = null);

	string toString();

	import std.json: JSONValue;
	JSONValue toStdJSON();
}
