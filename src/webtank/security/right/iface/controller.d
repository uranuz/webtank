module webtank.security.right.iface.controller;

import webtank.security.access_control: IUserIdentity;
import std.variant: Algebraic;
interface IRightController
{
	alias AllowedTypesVariant = Algebraic!(string[string], IvyData, JSONValue, IBaseRecord);
	
	bool hasRight(IUserIdentity user, string accessObject, string accessKind);
	bool hasRight(IUserIdentity user, string accessObject, string accessKind, string[string] data);
	bool hasRight(IUserIdentity user, string accessObject, string accessKind, IvyData data);
	bool hasRight(IUserIdentity user, string accessObject, string accessKind, JSONValue data);
	bool hasRight(IUserIdentity user, string accessObject, string accessKind, IBaseRecord data);
	bool hasRight(IUserIdentity user, string accessObject, string accessKind, AllowedTypesVariant data);
}