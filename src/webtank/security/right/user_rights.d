module webtank.security.right.user_rights;

import webtank.net.http.context: HTTPContext;
struct UserRights
{
private:
	HTTPContext _ctx;
public:
	bool isAllowed(string accessObject, string accessKind = null, string[string] data = null)
	{
		import std.exception: enforce;
		enforce(_ctx, `Access right controller is not set!!!`);
		enforce(_ctx.service, `HTTPContext service is not set!!!`);
		enforce(_ctx.service.rightController, `Service rights controller is not set!!!`);
		enforce(_ctx.user, `HTTPContext user identity is not set!!!`);
		return _ctx.service.rightController.isAllowed(_ctx.user, accessObject, accessKind, data);
	}
}