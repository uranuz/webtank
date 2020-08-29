module webtank.ivy.directive.to_json_base64;

import ivy.types.data: IvyDataType, IvyData;
import ivy.interpreter.directive.iface: IDirectiveInterpreter;
import ivy.interpreter.interpreter: Interpreter;
import ivy.directive_stuff: DirAttrKind, DirAttrsBlock, DirAttr;
import ivy.interpreter.directive: BaseNativeDirInterpreterImpl;

class ToJSONBase64DirInterpreter: IDirectiveInterpreter
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
			DirAttr("value", "any")
		]),
		DirAttrsBlock(DirAttrKind.BodyAttr)
	];

	mixin BaseNativeDirInterpreterImpl!("toJSONBase64");
}