module webtank.ivy.user;

import webtank.security.access_control: IUserIdentity;
import ivy.interpreter.data_node: IClassNode, DataNodeType, IDataNodeRange, DataNode;

class IvyUserIdentity: IClassNode
{
private:
	IUserIdentity _identity;
	alias TDataNode = DataNode!string;

public:
	import std.exception: enforce;
	this(IUserIdentity identity)
	{
		assert(identity !is null, `IUserIdentity object is null`);
		_identity = identity;
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
			import std.array: split;
			switch(attrName)
			{
				case `id`: return TDataNode(_identity.id);
				case `name`: return TDataNode(_identity.name);
				case `data`: return TDataNode(_identity.data);
				case `isAuthenticated`: return TDataNode(_identity.isAuthenticated);
				case `accessRoles`: return TDataNode(_identity.data.get(`accessRoles`, null).split(`;`));
				default: break;
			}
			throw new Exception(`Unexpected IvyUserIdentity attribute: ` ~ attrName);
		}

		void __setAttr__(TDataNode val, string attrName)
		{
			assert(false, "Method __setAttr__ not implemented");
		}
		
		TDataNode __serialize__() {
			assert(false, "Method __serialize__ not implemented");
		}
		
		size_t length() @property {
			assert(false, "Method length not implemented");
		}
	}
}