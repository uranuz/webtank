module webtank.ivy.datctrl.enum_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.deserialize;

import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;

import std.exception: enforce;

class EnumAdapter: IClassNode
{
private:
	EnumFormatAdapter _fmt;
	IvyData _value;

public:
	this(IvyData rawEnum)
	{
		_fmt = new EnumFormatAdapter(rawEnum);
		auto valPtr = "d" in rawEnum;
		enforce(valPtr, `Expected field "d" as enum value`);
		_value = _fmt[*valPtr]["value"]; // Just for validation
	}

	this(EnumFormatAdapter fmt, IvyData val) {
		_fmt = fmt;
		_value = _fmt[val]["value"]; // Just for validation
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
				case "name": return _fmt[_value]["name"];
				default: break;
			}
			throw new Exception(`Unexpected EnumAdapter property`);
		}

		void __setAttr__(IvyData value, string attrName) {
			throw new Exception(`Not attributes setting is yet supported by EnumAdapter`);
		}

		IvyData __serialize__() {
			IvyData res = _fmt.__serialize__();
			res["d"] = _value;
			return res;
		}

		size_t length() @property {
			throw new Exception(`length for EnumAdapter is not implemented yet`); 
		}
	}
}