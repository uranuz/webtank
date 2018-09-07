module webtank.security.right.iface.access_rule;

interface IAccessRule
{
	string name() @property;

	import webtank.security.access_control: IUserIdentity;
	bool hasRight(IUserIdentity identity);
	bool hasRight(IUserIdentity identity, string[string] data);
	bool hasRight(IUserIdentity identity, IvyData data);
	bool hasRight(IUserIdentity identity, JSONValue data);
	bool hasRight(IUserIdentity identity, IBaseRecord data);

	string toString();

	import std.json: JSONValue;
	JSONValue toStdJSON();
}
