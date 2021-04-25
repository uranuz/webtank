module webtank.ivy.opt_set;

import ivy.types.data.decl_class_node: DeclClassNode;

class OptSet: DeclClassNode
{
	import std.exception: enforce;

	import ivy.types.data: IvyData, IvyDataType;
	import ivy.interpreter.directive.base: IvyMethodAttr;
	import ivy.interpreter.interpreter: Interpreter;
	import ivy.types.data.decl_class: DeclClass, makeClass;
	import ivy.types.data.render: renderDataNode2;
	import ivy.types.data.render: DataRenderType;

private:
	IvyData _opts;

public:
	this(IvyData opts)
	{
		super(_declClass);

		this._opts = opts;
	}

	@IvyMethodAttr()
	IvyData __serialize__(Interpreter interp)
	{
		import std.base64: Base64;

		return IvyData(
			cast(string) Base64.encode(
				cast(ubyte[]) renderDataNode2!(DataRenderType.JSON)(this._opts, interp)));
	}

	@IvyMethodAttr()
	IvyData render(Interpreter interp) {
		return this.__serialize__(interp);
	}

	private __gshared DeclClass _declClass;

	shared static this()
	{
		_declClass = makeClass!(typeof(this))("OptSet");
	}
}