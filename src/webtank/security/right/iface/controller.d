module webtank.security.right.iface.controller;

import webtank.security.access_control: IUserIdentity;
interface IRightController
{
	bool hasRight(IUserIdentity user, string accessObject, string accessKind, string[string] data);
}