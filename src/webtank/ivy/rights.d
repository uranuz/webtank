module webtank.ivy.rights;

import webtank.security.right.user_rights: UserRights;
import ivy.interpreter.data_node: NotImplClassNode, IvyDataType, IvyNodeRange, IvyData;

class IvyUserRights: NotImplClassNode
{
private:
	UserRights _rights;
	string _accessObject;
	string _accessKind;
	IvyData _data = null; // Workaround for data not being undef and ivy node search not crash

public:
	import std.exception: enforce;
	this(UserRights rights)
	{
		_rights = rights;
	}

	override {
		IvyData __getAttr__(string attrName)
		{
			switch(attrName)
			{
				case `object`: return IvyData(_accessObject);
				case `kind`: return IvyData(_accessKind);
				case `data`: return _data;
				case `hasRight`: return IvyData(
					_rights.hasRight(_accessObject, _accessKind, _data));
				default: break;
			}
			throw new Exception(`Unexpected IvyUserRights attribute: ` ~ attrName);
		}

		void __setAttr__(IvyData val, string attrName)
		{
			import std.algorithm: canFind;
			switch(attrName)
			{
				case `object`:
				{
					// Access object is essential
					enforce(val.type == IvyDataType.String, `Expected string as access object name!!!`);
					_accessObject = val.str;
					break;
				}
				case `kind`:
				{
					// Access kind is optional
					enforce([IvyDataType.Undef, IvyDataType.Null, IvyDataType.String].canFind(val.type),
						`Expected string, null or undef as access kind name!!!`);
					if( val.type == IvyDataType.String ) {
						_accessKind = val.str;
					} else {
						_accessKind = null; // Need to clear it
					}
					break;
				}
				case `data`:
				{
					_data = val;
					break;
				}
				default:
					throw new Exception(`Unexpected IvyUserRights attribute: ` ~ attrName);
			}
		}

		IvyData __serialize__()
		{
			IvyData res;
			foreach( field; [`object`, `kind`, `data`, `hasRight`] ) {
				res[field] = this.__getAttr__(field);
			}
			return res;
		}
	}
}