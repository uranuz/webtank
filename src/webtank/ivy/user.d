module webtank.ivy.user;

import ivy.types.data.decl_class_node: DeclClassNode;

class IvyUserIdentity: DeclClassNode
{
	import ivy.types.data: IvyDataType, IvyData;
	import ivy.interpreter.directive.base: IvyMethodAttr;
	import ivy.types.data.decl_class: DeclClass, makeClass;

	import webtank.security.auth.iface.user_identity: IUserIdentity;

private:
	IUserIdentity _identity;

public:
	import std.exception: enforce;
	this(IUserIdentity identity)
	{
		super(_declClass);
		
		enforce(identity !is null, "IUserIdentity object is null");
		_identity = identity;
	}

	override {
		IvyData __getAttr__(string attrName)
		{
			import std.array: split;
			switch(attrName)
			{
				case "id": return IvyData(_identity.id);
				case "name": return IvyData(_identity.name);
				case "data": return IvyData(_identity.data);
				case "isAuthenticated": return IvyData(_identity.isAuthenticated);
				case "accessRoles": return IvyData(_identity.data.get("accessRoles", null).split(";"));
				default: break;
			}
			return super.__getAttr__(attrName);
		}
	}

	@IvyMethodAttr()
	IvyData __serialize__()
	{
		IvyData res;
		foreach( field; ["id", "name", "data", "isAuthenticated", "accessRoles"] ) {
			res[field] = this.__getAttr__(field);
		}
		return res;
	}

	private __gshared DeclClass _declClass;

	shared static this()
	{
		_declClass = makeClass!(typeof(this))("UserIdentity");
	}
}