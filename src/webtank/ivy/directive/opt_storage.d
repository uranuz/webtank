module webtank.ivy.directive.opt_storage;

import ivy.interpreter.directive.utils;
import webtank.ivy.opt_set: OptSet;

class OptStorageInterpreter: BaseDirectiveInterpreter
{
	this() {
		_symbol = new DirectiveSymbol("optStorage", [DirAttr("opts", IvyAttrType.Any)]);
	}
	
	override void interpret(Interpreter interp)
	{
		import std.algorithm: canFind;

		IvyData optsNode = interp.getValue("opts");
		interp.assure(
			[IvyDataType.AssocArray, IvyDataType.Null].canFind(optsNode.type),
			`Expected opts assoc array or null!`);

		interp._stack.push(new OptSet(optsNode));
	}
}