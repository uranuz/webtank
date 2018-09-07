module webtank.ivy.rights;

import webtank.security.right.user_rights: UserRights;
import ivy.interpreter.data_node: IClassNode, IvyDataType, IvyNodeRange, IvyData;

class IvyUserRights: IClassNode
{
private:
	UserRights _rights;
	string _accessObject;
	string _accessKind;
	IvyData _data;

public:
	import std.exception: enforce;
	this(UserRights rights)
	{
		_rights = rights;
	}

	override {
		IvyNodeRange opSlice() {
			assert(false, "Method opSlice not implemented");
		}

		IClassNode opSlice(size_t, size_t) {
			assert(false, "Method opSlice not implemented");
		}

		IvyData opIndex(string) {
			assert(false, "Method opIndex not implemented");
		}

		IvyData opIndex(size_t) {
			assert(false, "Method opIndex not implemented");
		}

		IvyData __getAttr__(string attrName)
		{
			switch(attrName)
			{
				case `object`: return IvyData(_accessObject);
				case `kind`: return IvyData(_accessKind);
				case `data`: return IvyData(_data);
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
		
		IvyData __serialize__() {
			assert(false, "Method __serialize__ not implemented");
		}
		
		size_t length() @property {
			assert(false, "Method length not implemented");
		}
	}
}