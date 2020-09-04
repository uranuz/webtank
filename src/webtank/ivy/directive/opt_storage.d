module webtank.ivy.directive.opt_storage;

import ivy.interpreter.directive.utils;

import ivy.types.data.not_impl_class_node: NotImplClassNode;

class OptStorage: NotImplClassNode
{
	import ivy.types.data: IvyData, IvyDataType;

private:
	IvyData _opts;

public:
	import std.exception: enforce;
	this(IvyData opts)
	{
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
		
		size_t length() @property {
			throw new Exception("Method length not implemented");
		}
	}
}


class OptStorageInterpreter: BaseDirectiveInterpreter
{
	shared static this() {
		_symbol = new DirectiveSymbol(`optStorage`, [DirAttr("opts", IvyAttrType.Any)]);
	}
	
	override void interpret(Interpreter interp)
	{
		import std.algorithm: canFind;

		IvyData optsNode = interp.getValue("opts");
		interp.log.internalAssert(
			[IvyDataType.AssocArray, IvyDataType.Null].canFind(optsNode.type),
			`Expected opts assoc array or null!`);

		interp._stack.push(new OptStorage(optsNode));
	}
}