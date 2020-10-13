module webtank.ivy.directive.to_json_base64;

import ivy.interpreter.directive.utils;

class ToJSONBase64DirInterpreter: BaseDirectiveInterpreter
{
	this() {
		_symbol = new DirectiveSymbol("toJSONBase64", [DirAttr("value", IvyAttrType.Any)]);
	}

	override void interpret(Interpreter interp)
	{
		import std.base64: Base64;
		ubyte[] jsonStr = cast(ubyte[]) interp.getValue("value").toJSONString();
		interp._stack.push(cast(string) Base64.encode(jsonStr));
	}
}