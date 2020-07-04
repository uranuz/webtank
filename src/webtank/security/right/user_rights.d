module webtank.security.right.user_rights;

import webtank.security.right.common: RightDataTypes, RightDataVariant;
import webtank.security.right.access_exception: AccessSystemException, AccessException;

import webtank.net.http.context: HTTPContext;
struct UserRights
{
private:
	HTTPContext _ctx;
public:
	// Checke wheter all fields we need are initialized
	private void _checkPreconditions()
	{
		import std.exception: enforce;
		enforce!AccessSystemException(_ctx !is null, `Access right controller is not set!!!`);
		enforce!AccessSystemException(_ctx.service !is null, `HTTPContext service is not set!!!`);
		enforce!AccessSystemException(_ctx.service.rightController !is null, `Service rights controller is not set!!!`);
		enforce!AccessException(_ctx.user !is null, `HTTPContext user identity is not set!!!`);
	}

	static foreach( alias RightType; RightDataTypes )
	{
		bool hasRight(string accessObject, string accessKind, RightType data) {
			// We shall pack allowed data types into Variant
			return hasRight(accessObject, accessKind, RightDataVariant(data));
		}
	}

	bool hasRight(string accessObject, string accessKind = null, RightDataVariant data = RightDataVariant())
	{
		_checkPreconditions();
		return _ctx.service.rightController.hasRight(_ctx.user, accessObject, accessKind, data);
	}
}