module webtank.ivy.rights;

import webtank.security.right.user_rights: UserRights;
import ivy.interpreter.data_node: IClassNode, DataNodeType, IDataNodeRange, DataNode;

class IvyUserRights: IClassNode
{
private:
	UserRights _rights;
	string _accessObject;
	string _accessKind;
	string[string] _data;
	alias TDataNode = DataNode!string;

public:
	import std.exception: enforce;
	this(UserRights rights)
	{
		_rights = rights;
	}

	override {
		IDataNodeRange opSlice() {
			assert(false, "Method opSlice not implemented");
		}

		IClassNode opSlice(size_t, size_t) {
			assert(false, "Method opSlice not implemented");
		}

		TDataNode opIndex(string) {
			assert(false, "Method opIndex not implemented");
		}

		TDataNode opIndex(size_t) {
			assert(false, "Method opIndex not implemented");
		}

		TDataNode __getAttr__(string attrName)
		{
			switch(attrName)
			{
				case `object`: return TDataNode(_accessObject);
				case `kind`: return TDataNode(_accessKind);
				case `data`: return TDataNode(_data);
				case `isAllowed`: return TDataNode(
					_rights.isAllowed(_accessObject, _accessKind, _data));
				default: break;
			}
			throw new Exception(`Unexpected IvyUserRights attribute: ` ~ attrName);
		}

		void __setAttr__(TDataNode val, string attrName)
		{
			import std.algorithm: canFind;
			switch(attrName)
			{
				case `object`:
				{
					// Access object is essential
					enforce(val.type == DataNodeType.String, `Expected string as access object name!!!`);
					_accessObject = val.str;
					break;
				}
				case `kind`:
				{
					// Access kind is optional
					enforce([DataNodeType.Undef, DataNodeType.Null, DataNodeType.String].canFind(val.type),
						`Expected string, null or undef as access kind name!!!`);
					if( val.type == DataNodeType.String ) {
						_accessKind = val.str;
					} else {
						_accessKind = null; // Need to clear it
					}
					break;
				}
				case `data`:
				{
					enforce([DataNodeType.Undef, DataNodeType.Null, DataNodeType.AssocArray].canFind(val.type),
						`Expected assoc array, null or undef as access kind name!!!`);
					_data.clear(); // Clear data at the start of set
					if( val.type == DataNodeType.AssocArray )
					{
						foreach( string name, TDataNode node; val.assocArray )
						{
							enforce(node.type == DataNodeType.String, `Data item expected to be a string!!!`);
							_data[name] = node.str; // Fill data
						}
					}
					break;
				}
				default:
					throw new Exception(`Unexpected IvyUserRights attribute: ` ~ attrName);
			}
		}
		
		TDataNode __serialize__() {
			assert(false, "Method __serialize__ not implemented");
		}
		
		size_t length() @property {
			assert(false, "Method length not implemented");
		}
	}
}