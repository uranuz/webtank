module webtank.ivy.datctrl.record_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.deserialize;

class RecordAdapter: IClassNode
{
	alias TDataNode = DataNode!string;
private:
	TDataNode _rawRec;
	size_t[string] _namesMapping;

public:
	this(TDataNode rawRec, size_t[string] namesMapping)
	{
		_rawRec = rawRec;
		_ensureRecord();
		_namesMapping = namesMapping;
		_deserializeInplace();
	}

	this(TDataNode rawRec)
	{
		_rawRec = rawRec;
		_ensureRecord();

		foreach( i, fmt; _rawFormat.array )
		{
			assert( "n" in fmt, `Expected name field "n" in record raw format` );
			_namesMapping[ fmt["n"].str ] = i;
		}
		_deserializeInplace();
	}

	void _ensureRecord()
	{
		assert( "t" in _rawRec, `Expected type field "t" in record raw data!` );
		assert( "d" in _rawRec, `Expected data field "d" in record raw data!` );
		assert( "f" in _rawRec, `Expected format field "f" in record raw data!` );
		assert( _rawRec["t"].type == DataNodeType.String && _rawRec["t"].str == "record", `Expected "record" value in "t" field` );
	}

	void _deserializeInplace()
	{
		foreach( i, ref fieldData; _rawData.array ) {
			_deserializeFieldInplace(fieldData, _rawFormat[i]);
		}
	}

	TDataNode _rawData() @property {
		return _rawRec["d"];
	}

	TDataNode _rawFormat() @property {
		return _rawRec["f"];
	}

	static class Range: IDataNodeRange
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
				return i >= _rec._rawData.array.length;
			}

			TDataNode front() {
				return _rec._rawData[i];
			}

			void popFront() {
				++i;
			}

			DataNodeType aggrType() @property
			{
				return DataNodeType.Array;
			}
		}
	}

	override IDataNodeRange opSlice() {
		return new Range(this);
	}

	override TDataNode opIndex(size_t index)
	{
		import std.conv: text;
		assert(index < _rawData.array.length, `Record column with index ` ~ index.text ~ ` is not found!`);
		return _rawData[index];
	}

	override TDataNode opIndex(string key)
	{
		assert(key in _namesMapping, `Record column with name "` ~ key ~ `" is not found!`);
		return _rawData[ _namesMapping[key] ];
	}

	override TDataNode __getAttr__(string attrName)
	{
		switch(attrName)
		{
			case "format": return _rawFormat;
			case "namesMapping": return TDataNode(_namesMapping);
			default: break;
		}
		return TDataNode();
	}

	override void __setAttr__(TDataNode value, string attrName) {
		assert(false, `Not attributes setting is yet supported by RecordAdapter`);
	}

	override TDataNode __serialize__() {
		// Maybe we should make deep copy of it there, but because of productivity
		// we shall not do it now. Just say for now that nobody should modifiy serialized data
		return _rawRec;
	}
}