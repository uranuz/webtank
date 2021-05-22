module webtank.ivy.datctrl.field_format_adapter;

import ivy.types.data.decl_class_node: DeclClassNode;

class FieldFormatAdapter: DeclClassNode
{
	import ivy.types.data: IvyData, IvyDataType;

	import webtank.datctrl.consts: SrlField;

	import ivy.interpreter.directive.utils: IvyMethodAttr;
	import ivy.types.data.decl_class: DeclClass;
	import ivy.types.data.decl_class_utils: makeClass;

	import std.exception: enforce;
private:
	IvyData _rawField;
public:
	this(IvyData rawField)
	{
		super(_declClass);

		_rawField = rawField;

		enforce(SrlField.type in _rawField, `Expected type field "` ~ SrlField.type ~ `" in field format raw data!`);
		enforce(SrlField.name in _rawField, `Expected name field "` ~ SrlField.name ~ `" in field format raw data!`);
	}

	override {
		IvyData __getAttr__(string attrName)
		{
			switch(attrName)
			{
				case "name": return _rawField[SrlField.name];
				case "typeStr": return _rawField[SrlField.type];
				default: break;
			}
			return super.__getAttr__(attrName);
		}
	}

	string typeStr() @property {
		return _rawField[SrlField.type].str;
	}

	@IvyMethodAttr()
	IvyData __serialize__() {
		// Maybe we should make deep copy of it there, but because of productivity
		// we shall not do it now. Just say for now that nobody should modifiy serialized data
		return _rawField;
	}

	private __gshared DeclClass _declClass;

	shared static this()
	{
		_declClass = makeClass!(typeof(this))("FieldFormatAdapter");
	}

}