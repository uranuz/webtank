module webtank.ivy.datctrl.record_format_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;

import std.exception: enforce;
import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;
import webtank.ivy.datctrl.field_format_adapter: FieldFormatAdapter;

class RecordFormatAdapter: IClassNode
{
private:
	IvyData _rawData;
	size_t[string] _namesMapping;

public:
	this(IvyData rawData)
	{
		_rawData = rawData;
		enforce(_rawData.type == IvyDataType.AssocArray, `Record format raw data must be object`);
		enforce("f" in _rawData, `Expected format field "f" in record raw data!`);

		foreach( i, fmt; _rawFormat.array )
		{
			enforce("n" in fmt, `Expected name field "n" for field in raw record format`);
			enforce("t" in fmt, `Expected type field "t" for field in raw record format`);
			_namesMapping[ fmt["n"].str ] = i;
			if( fmt["t"].str == "enum" ) {
				_rawFormat[i] = new EnumFormatAdapter(fmt);
			} else {
				_rawFormat[i] = new FieldFormatAdapter(fmt);
			}
		}
	}

	IvyData _rawFormat() @property {
		return _rawData["f"];
	}

	size_t[string] namesMapping() @property {
		return _namesMapping;
	}

	static class Range: IvyNodeRange
	{
	private:
		RecordFormatAdapter _fmt;
		size_t i = 0;

	public:
		this(RecordFormatAdapter fmt) {
			_fmt = fmt;
		}

		override {
			bool empty() @property {
				return i >= _fmt.length;
			}

			IvyData front() {
				return _fmt[IvyData(i)];
			}

			void popFront() {
				++i;
			}
		}
	}


	override {
		IvyNodeRange opSlice() {
			return new Range(this);
		}

		IClassNode opSlice(size_t, size_t) {
			throw new Exception(`opSlice for RecordFormatAdapter is not implemented yet`);
		}

		IvyData opIndex(IvyData index)
		{
			import std.conv: text;
			switch( index.type )
			{
				case IvyDataType.Integer: {
					enforce(index.integer < _rawFormat.length, `Record format column with index ` ~ index.integer.text ~ ` is not found!`);
					return _rawFormat[index.integer];
				}
				case IvyDataType.String: {
					enforce(index.str in _namesMapping, `Record format column with name "` ~ index.str ~ `" is not found!`);
					return _rawFormat[ _namesMapping[index.str] ];
				}
				default: break;
			}
			throw new Exception(`Unexpected kind of index argument: ` ~ index.type.text);
		}

		IvyData __getAttr__(string attrName)
		{
			return IvyData();
		}

		void __setAttr__(IvyData value, string attrName) {
			enforce(false, `No attributes setting is yet supported by RecordFormatAdapter`);
		}

		IvyData __serialize__() {
			// Maybe we should make deep copy of it there, but because of productivity
			// we shall not do it now. Just say for now that nobody should modifiy serialized data
			return _rawData;
		}

		size_t length() @property {
			return _rawFormat.length;
		}
	}
}