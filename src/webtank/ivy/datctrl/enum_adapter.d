module webtank.ivy.datctrl.enum_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.interpreter.data_node;
import webtank.ivy.datctrl.deserialize;

import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;

import std.exception: enforce;

import webtank.datctrl.consts;

class EnumAdapter: IClassNode
{
private:
	EnumFormatAdapter _fmt;
	IvyData _value;

public:
	this(IvyData rawEnum)
	{
		
		_fmt = new EnumFormatAdapter(rawEnum);
		auto valPtr = WT_DATA_FIELD in rawEnum;
		enforce(valPtr, `Expected field "` ~ WT_DATA_FIELD ~ `" as enum value`);
		enforce(hasValueOrEmpty(*valPtr), `There is such no value in enum`);
		_value = *valPtr; // Just for validation
	}

	this(EnumFormatAdapter fmt, IvyData val)
	{
		_fmt = fmt;

		enforce(fmt !is null, `Enum format is null`);
		enforce(hasValueOrEmpty(val), `There is such no value in enum`);
		_value = val;
	}

	bool hasValueOrEmpty(IvyData val)
	{
		import std.algorithm: canFind;
		return _fmt.hasValue(val) || [IvyDataType.Undef, IvyDataType.Null].canFind(val.type);
	}

	override {
		IvyNodeRange opSlice() {
			throw new Exception(`opSlice for EnumAdapter is not implemented yet`);
		}

		IClassNode opSlice(size_t, size_t) {
			throw new Exception(`opSlice for EnumAdapter is not implemented yet`);
		}

		IvyData opIndex(IvyData index) {
			throw new Exception(`opIndex for EnumAdapter is not implemented yet`); 
		}

		IvyData __getAttr__(string attrName)
		{
			switch(attrName)
			{
				case "format": return IvyData(_fmt);
				case "value": return _value;
				case "name": return _fmt.names[_value];
				default: break;
			}
			throw new Exception(`Unexpected EnumAdapter property`);
		}

		void __setAttr__(IvyData value, string attrName) {
			throw new Exception(`Not attributes setting is yet supported by EnumAdapter`);
		}

		IvyData __serialize__()
		{
			IvyData res = _fmt.__serialize__();
			res[WT_DATA_FIELD] = _value;
			return res;
		}

		size_t length() @property {
			throw new Exception(`length for EnumAdapter is not implemented yet`); 
		}
	}
}