module webtank.ivy.opt_set;

import ivy.types.data.base_class_node: BaseClassNode;

class OptSet: BaseClassNode
{
	import ivy.types.data: IvyData, IvyDataType;

private:
	IvyData _opts;

public:
	this(IvyData opts) {
		_opts = opts;
	}

	override {
		IvyData __serialize__()
		{
			import std.base64: Base64;
			return IvyData(
				cast(string) Base64.encode(
					cast(ubyte[]) _opts.toJSONString()));
		}
	}
}