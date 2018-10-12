module webtank.ivy.datctrl.record_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.deserialize;

import webtank.ivy.datctrl.record_format_adapter: RecordFormatAdapter;

import std.exception: enforce;

class RecordAdapter: IClassNode
{
private:
	IvyData _rawRec;
	RecordFormatAdapter _fmt;

public:
	this(IvyData rawRec, RecordFormatAdapter fmt)
	{
		_rawRec = rawRec;
		_ensureRecord();
		_fmt = fmt;
		enforce(_rawData.length == _fmt.length, `Raw record field count must match format field count`);
		_deserializeInplace();
	}

	this(IvyData rawRec)
	{
		_rawRec = rawRec;
		_ensureRecord();
		_fmt = new RecordFormatAdapter(rawRec);
		_deserializeInplace();
	}

	void _ensureRecord()
	{
		enforce("t" in _rawRec, `Expected type field "t" in record raw data!`);
		enforce("d" in _rawRec, `Expected data field "d" in record raw data!`);
		enforce("f" in _rawRec, `Expected format field "f" in record raw data!`);
		enforce(
			_rawRec["t"].type == IvyDataType.String && _rawRec["t"].str == "record",
			`Expected "record" value in "t" field`
		);
	}

	void _deserializeInplace()
	{
		foreach( i, ref fieldData; _rawData.array ) {
			_deserializeFieldInplace(fieldData, _fmt[i]);
		}
	}

	IvyData _rawData() @property {
		return _rawRec["d"];
	}

	static class Range: IvyNodeRange
	{
	private:
		RecordAdapter _rec;
		size_t i = 0;

	public:
		this(RecordAdapter record) {
			_rec = record;
		}

		override {
			bool empty() @property
			{
				import std.range: empty;
				return i >= _rec._rawData.length;
			}

			IvyData front() {
				return _rec._rawData[i];
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
			assert(false, `opSlice for RecordAdapter is not implemented yet`);
		}

		IvyData opIndex(size_t index)
		{
			import std.conv: text;
			enforce(index < _rawData.array.length, `Record column with index ` ~ index.text ~ ` is not found!`);
			return _rawData[index];
		}

		IvyData opIndex(string key)
		{
			enforce(key in _fmt.namesMapping, `Record column with name "` ~ key ~ `" is not found!`);
			return _rawData[ _fmt.namesMapping[key] ];
		}

		IvyData __getAttr__(string attrName)
		{
			switch(attrName)
			{
				case "format": return IvyData(_fmt);
				default: break;
			}
			return IvyData();
		}

		void __setAttr__(IvyData value, string attrName) {
			enforce(false, `Not attributes setting is yet supported by RecordAdapter`);
		}

		IvyData __serialize__() {
			// Maybe we should make deep copy of it there, but because of productivity
			// we shall not do it now. Just say for now that nobody should modifiy serialized data
			return _rawRec;
		}

		size_t length() @property {
			return _fmt.length;
		}
	}

	
}