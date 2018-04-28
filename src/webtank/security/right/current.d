module webtank.security.right.current;

import webtank.security.access_control: IUserIdentity;
import webtank.security.right.controller: AccessRightController;

class CurrentUserRights
{
private:
	IUserIdentity _user;
	AccessRightController _controller;
public:
	bool isAllowed(string accessObject, string accessKind = null, string[string] data = null)
	{
		import std.exception: enforce;
		enforce(_controller, `Access right controller is not set!!!`);
		enforce(_user, `Access right controller is not set!!!`);
		return _controller.isAllowed(_user, accessObject, data);
	}
}