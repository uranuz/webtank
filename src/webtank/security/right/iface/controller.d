module webtank.security.right.iface.controller;

import webtank.security.access_control: IUserIdentity;
interface IRightController
{
	bool isAllowed(IUserIdentity user, string accessObject, string accessKind, string[string] data);
}