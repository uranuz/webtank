module webtank.ivy.directive.opt_storage;

import ivy.interpreter.data_node: IvyDataType, IvyNodeRange, IvyData, IClassNode;
import ivy.interpreter.iface: INativeDirectiveInterpreter;
import ivy.interpreter.interpreter: Interpreter;
import ivy.directive_stuff: DirAttrKind, DirAttrsBlock, DirValueAttr;
import ivy.interpreter.directive: BaseNativeDirInterpreterImpl;

class OptStorage: IClassNode
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
		IvyNodeRange opSlice() {
			throw new Exception("Method opSlice is not implemented");
		}

		IClassNode opSlice(size_t, size_t) {
			throw new Exception("Method opSlice is not implemented");
		}

		IvyData opIndex(IvyData) {
			throw new Exception("Method opIndex is not implemented");
		}

		IvyData __getAttr__(string attrName)
		{
			throw new Exception("Method __getAttr__ is not implemented");
		}

		void __setAttr__(IvyData val, string attrName)
		{
			throw new Exception("Method __setAttr__ is not implemented");
		}
		
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
		interp.loger.internalAssert(
			[IvyDataType.AssocArray, IvyDataType.Null].canFind(optsNode.type),
			`Expected opts assoc array or null!`);

		interp._stack ~= IvyData(new OptStorage(optsNode));
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