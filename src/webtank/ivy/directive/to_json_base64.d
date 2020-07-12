module webtank.ivy.directive.to_json_base64;

import ivy.interpreter.data_node: IvyDataType, IvyData;
import ivy.interpreter.iface: INativeDirectiveInterpreter;
import ivy.interpreter.interpreter: Interpreter;
import ivy.directive_stuff: DirAttrKind, DirAttrsBlock, DirValueAttr;
import ivy.interpreter.directive: BaseNativeDirInterpreterImpl;

class ToJSONBase64DirInterpreter: INativeDirectiveInterpreter
{
	import std.typecons: Tuple;

	override void interpret(Interpreter interp)
	{
		import std.base64: Base64;
		ubyte[] jsonStr = cast(ubyte[]) interp.getValue("value").toJSONString();
		interp._stack.push(cast(string) Base64.encode(jsonStr));
	}

	private __gshared DirAttrsBlock[] _attrBlocks = [
		DirAttrsBlock(DirAttrKind.ExprAttr, [
			DirValueAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("toJSONBase64");
}