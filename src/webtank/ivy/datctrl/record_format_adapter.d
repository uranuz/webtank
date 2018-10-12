module webtank.ivy.datctrl.record_format_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;

import std.exception: enforce;

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
			enforce("n" in fmt, `Expected name field "n" in raw record format`);
			_namesMapping[ fmt["n"].str ] = i;
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
				return _fmt[i];
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
			assert(false, `opSlice for RecordFormatAdapter is not implemented yet`);
		}

		IvyData opIndex(size_t index)
		{
			import std.conv: text;
			enforce(index < _rawFormat.length, `Record format column with index ` ~ index.text ~ ` is not found!`);
			return _rawFormat[index];
		}

		IvyData opIndex(string key)
		{
			enforce(key in _namesMapping, `Record format column with name "` ~ key ~ `" is not found!`);
			return _rawFormat[ _namesMapping[key] ];
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