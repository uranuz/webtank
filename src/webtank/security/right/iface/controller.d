module webtank.security.right.iface.controller;

import webtank.security.access_control: IUserIdentity;
import std.variant: Algebraic;
import std.json: JSONValue;
import webtank.security.right.common: RightDataTypes, RightDataVariant;

interface IRightController
{
	// This is main hasRight method...s
	bool hasRight(IUserIdentity user, string accessObject, string accessKind, RightDataVariant data = RightDataVariant());

	// ...generate extra hasRight overloads for convenience
	static foreach( alias RightType; RightDataTypes ) {
		bool hasRight(IUserIdentity user, string accessObject, string accessKind, RightType data);	
	}
}


