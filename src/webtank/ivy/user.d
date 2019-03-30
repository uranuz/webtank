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
		enforce(identity !is null, `IUserIdentity object is null`);
		_identity = identity;
	}

	override {
		IvyNodeRange opSlice() {
			throw new Exception("Method opSlice not implemented");
		}

		IClassNode opSlice(size_t, size_t) {
			throw new Exception("Method opSlice not implemented");
		}

		IvyData opIndex(IvyData) {
			throw new Exception("Method opIndex not implemented");
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

		void __setAttr__(IvyData val, string attrName) {
			throw new Exception("Method __setAttr__ not implemented");
		}
		
		IvyData __serialize__() {
			IvyData res;
			foreach( field; [`id`, `name`, `data`, `isAuthenticated`, `accessRoles`] ) {
				res[field] = this.__getAttr__(field);
			}
			return res;
		}
		
		size_t length() @property {
			throw new Exception("Method length not implemented");
		}
	}
}