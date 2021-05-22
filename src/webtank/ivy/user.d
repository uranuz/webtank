module webtank.ivy.user;

import ivy.types.data.decl_class_node: DeclClassNode;

class IvyUserIdentity: DeclClassNode
{
	import ivy.types.data: IvyDataType, IvyData;
	import ivy.interpreter.directive.utils: IvyMethodAttr;
	import ivy.types.data.decl_class: DeclClass;
	import ivy.types.data.decl_class_utils: makeClass;
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.consts: IvyAttrType;

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
			
			switch(attrName)
			{
				case "id": return IvyData(this._identity.id);
				case "name": return IvyData(this._identity.name);
				case "data": return IvyData(this._identity.data);
				case "isAuthenticated": return IvyData(this._identity.isAuthenticated);
				case "accessRoles": return IvyData(this._accessRoles);
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

	string[] _accessRoles() @property
	{
		import std.array: split;
		return this._identity.data.get("accessRoles", null).split(";");
	}

	@IvyMethodAttr(null, [
		DirAttr("role", IvyAttrType.Any)
	])
	bool isInRole(string role)
	{
		import std.algorithm: canFind;
		return this._accessRoles.canFind(role);
	}

	private __gshared DeclClass _declClass;

	shared static this()
	{
		_declClass = makeClass!(typeof(this))("UserIdentity");
	}
}