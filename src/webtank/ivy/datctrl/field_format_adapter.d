module webtank.ivy.datctrl.field_format_adapter;

import ivy.types.data.base_class_node: BaseClassNode;

class FieldFormatAdapter: BaseClassNode
{
	import ivy.types.data: IvyData, IvyDataType;

	import webtank.datctrl.consts: SrlField;

	import std.exception: enforce;
private:
	IvyData _rawField;
public:
	this(IvyData rawField)
	{
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
			throw new Exception(`Unexpected attribute name for FieldFormatAdapter`);
		}
		IvyData __serialize__() {
			// Maybe we should make deep copy of it there, but because of productivity
			// we shall not do it now. Just say for now that nobody should modifiy serialized data
			return _rawField;
		}
	}

	string typeStr() @property {
		return _rawField[SrlField.type].str;
	}
}