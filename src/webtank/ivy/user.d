module webtank.ivy.user;

import ivy.types.data.base_class_node: BaseClassNode;

class IvyUserIdentity: BaseClassNode
{
	import webtank.security.auth.iface.user_identity: IUserIdentity;
	import ivy.types.data: IvyDataType, IvyData;

private:
	IUserIdentity _identity;

public:
	import std.exception: enforce;
	this(IUserIdentity identity)
	{
		enforce(identity !is null, `IUserIdentity object is null`);
		_identity = identity;
	}

	override {
		IvyData __getAttr__(string attrName)
		{
			import std.array: split;
			switch(attrName)
			{
				case `id`: return IvyData(_identity.id);
				case `name`: return IvyData(_identity.name);
				case `data`: return IvyData(_identity.data);
				case `isAuthenticated`: return IvyData(_identity.isAuthenticated);
				case `accessRoles`: return IvyData(_identity.data.get(`accessRoles`, null).split(`;`));
				default: break;
			}
			throw new Exception(`Unexpected IvyUserIdentity attribute: ` ~ attrName);
		}

		IvyData __serialize__()
		{
			IvyData res;
			foreach( field; [`id`, `name`, `data`, `isAuthenticated`, `accessRoles`] ) {
				res[field] = this.__getAttr__(field);
			}
			return res;
		}
	}
}