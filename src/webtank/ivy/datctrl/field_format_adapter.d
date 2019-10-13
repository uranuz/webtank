module webtank.ivy.datctrl.field_format_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.deserialize;

import std.exception: enforce;

import webtank.datctrl.consts;

class FieldFormatAdapter: IClassNode
{
private:
	IvyData _rawField;
public:
	this(IvyData rawField)
	{
		_rawField = rawField;

		enforce(WT_TYPE_FIELD in _rawField, `Expected type field "` ~ WT_TYPE_FIELD ~ `" in field format raw data!`);
		enforce(WT_NAME_FIELD in _rawField, `Expected name field "` ~ WT_NAME_FIELD ~ `" in field format raw data!`);
	}

	override {
		IvyNodeRange opSlice() {
			throw new Exception(`opSlice for FieldFormatAdapter is not implemented yet`);
		}

		IClassNode opSlice(size_t, size_t) {
			throw new Exception(`opSlice for FieldFormatAdapter is not implemented yet`);
		}

		IvyData opIndex(IvyData index) {
			throw new Exception(`opIndex for FieldFormatAdapter is not implemented yet`);
		}

		IvyData __getAttr__(string attrName)
		{
			switch(attrName)
			{
				case "name": return _rawField[WT_NAME_FIELD];
				case "typeStr": return _rawField[WT_TYPE_FIELD];
				default: break;
			}
			throw new Exception(`Unexpected attribute name for FieldFormatAdapter`);
		}

		void __setAttr__(IvyData value, string attrName) {
			throw new Exception(`__setAttr__ for FieldFormatAdapter is not implemented yet`);
		}

		IvyData __serialize__() {
			// Maybe we should make deep copy of it there, but because of productivity
			// we shall not do it now. Just say for now that nobody should modifiy serialized data
			return _rawField;
		}

		size_t length() @property {
			throw new Exception(`length for FieldFormatAdapter is not implemented yet`);
		}
	}

	string typeStr() @property {
		return _rawField[WT_TYPE_FIELD].str;
	}
}