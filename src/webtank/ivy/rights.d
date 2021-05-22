module webtank.ivy.rights;

import ivy.types.data.decl_class_node: DeclClassNode;

class IvyUserRights: DeclClassNode
{
	import ivy.types.data: IvyDataType, IvyData;
	import ivy.interpreter.directive.utils: IvyMethodAttr;
	import ivy.types.data.decl_class: DeclClass;
	import ivy.types.data.decl_class_utils: makeClass;
	import ivy.types.symbol.dir_attr: DirAttr;
	import ivy.types.symbol.consts: IvyAttrType;


	import webtank.security.right.user_rights: UserRights;

private:
	UserRights _rights;
	string _accessObject;
	string _accessKind;
	IvyData _data = null; // Workaround for data not being undef and ivy node search not crash

public:
	this(UserRights rights)
	{
		super(_declClass);

		this._rights = rights;
	}

	@IvyMethodAttr(null, [
		DirAttr("object", IvyAttrType.Any),
		DirAttr("kind", IvyAttrType.Any),
		DirAttr("data", IvyAttrType.Any)
	])
	bool hasRight(string object, string kind, IvyData data) {
		return this._rights.hasRight(object, kind, data);
	}

	private __gshared DeclClass _declClass;

	shared static this()
	{
		_declClass = makeClass!(typeof(this))("UserRights");
	}
}