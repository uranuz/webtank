module webtank.datctrl.enum_;

import webtank.datctrl.enum_format: EnumFormat;

struct Enum(T, bool withNames)
{
	alias Format = EnumFormat!(T, withNames);
	private Format _format;
	private T _value;

	this(Format fmt, T val) {
		_format = fmt;
		_value = val;
	}

	T value() @property {
		return _value;
	}
	
	void value(ref T val) {
		import std.exception: enforce;
		enforce(_format.hasValue(val), `Incorrect enum value`);
		_value = val;
	}

	static if( withNames )
	{
		string name() @property {
			return _fmt.getName(_value);
		}

		void name(string nm) @property {
			_value = _fmt.getValue(nm);
		}
	}

	Format format() @property {
		return _format;
	}

	JSONValue toStdJSON() inout
	{
		import webtank.common.std_json: toStdJSON;
		JSONValue res = _format.toStdJSON();
		res["d"] = _value.toStdJSON();
		return res;
	}
}