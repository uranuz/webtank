module webtank.ivy.datctrl.enum_adapter;

import ivy.types.data.not_impl_class_node: NotImplClassNode;

class EnumAdapter: NotImplClassNode
{
	import ivy.types.data: IvyData, IvyDataType;

	import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;
	import webtank.datctrl.consts: SrlField;

	import std.exception: enforce;

private:
	EnumFormatAdapter _fmt;
	IvyData _value;

public:
	this(IvyData rawEnum)
	{
		
		_fmt = new EnumFormatAdapter(rawEnum);
		auto valPtr = SrlField.data in rawEnum;
		enforce(valPtr, `Expected field "` ~ SrlField.data ~ `" as enum value`);
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

		IvyData __serialize__()
		{
			IvyData res = _fmt.__serialize__();
			res[SrlField.data] = _value;
			return res;
		}
	}
}