module webtank.ivy.user;

import webtank.security.access_control: IUserIdentity;
import ivy.interpreter.data_node: IClassNode, IvyDataType, IvyNodeRange, IvyData;

class IvyUserIdentity: IClassNode
{
private:
	IUserIdentity _identity;

public:
	import std.exception: enforce;
	this(IUserIdentity identity)
	{
		assert(identity !is null, `IUserIdentity object is null`);
		_identity = identity;
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

		void __setAttr__(IvyData val, string attrName)
		{
			assert(false, "Method __setAttr__ not implemented");
		}
		
		IvyData __serialize__() {
			assert(false, "Method __serialize__ not implemented");
		}
		
		size_t length() @property {
			assert(false, "Method length not implemented");
		}
	}
}