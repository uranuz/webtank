module webtank.ivy.directive.opt_storage;

import ivy.interpreter.data_node: IvyDataType, IvyNodeRange, IvyData, NotImplClassNode;
import ivy.interpreter.iface: INativeDirectiveInterpreter;
import ivy.interpreter.interpreter: Interpreter;
import ivy.directive_stuff: DirAttrKind, DirAttrsBlock, DirValueAttr;
import ivy.interpreter.directive: BaseNativeDirInterpreterImpl;

class OptStorage: NotImplClassNode
{
private:
	IvyData _opts;

public:
	import std.exception: enforce;
	this(IvyData opts)
	{
		_opts = opts;
	}

	override {
		IvyData __serialize__() {
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


class OptStorageInterpreter: INativeDirectiveInterpreter
{
	override void interpret(Interpreter interp)
	{
		import std.algorithm: canFind;
		IvyData optsNode = interp.getValue("opts");
		interp.log.internalAssert(
			[IvyDataType.AssocArray, IvyDataType.Null].canFind(optsNode.type),
			`Expected opts assoc array or null!`);

		interp._stack.push(new OptStorage(optsNode));
	}

	private __gshared DirAttrsBlock[] _attrBlocks;
	shared static this()
	{
		_attrBlocks = [
			DirAttrsBlock( DirAttrKind.ExprAttr, [
				DirValueAttr("opts", "any")
			]),
			DirAttrsBlock(DirAttrKind.BodyAttr)
		];
	}

	mixin BaseNativeDirInterpreterImpl!("optStorage");
}