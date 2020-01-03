module webtank.security.right.iface.access_rule;

import webtank.datctrl.iface.record: IBaseRecord;
import webtank.security.right.common: RightDataTypes, RightDataVariant;
import std.json: JSONValue;


interface IAccessRule
{
	string name() @property;

	import webtank.security.auth.iface.user_identity: IUserIdentity;

	// This is main hasRight method...
	bool hasRight(IUserIdentity identity, RightDataVariant data = RightDataVariant());

	// ... generate extra hasRight overloads for convenience
	static foreach( alias RightType; RightDataTypes ) {
		bool hasRight(IUserIdentity identity, RightType data);
	}

	string toString();

	import std.json: JSONValue;
	JSONValue toStdJSON();
}
