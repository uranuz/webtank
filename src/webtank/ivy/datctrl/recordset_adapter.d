module webtank.ivy.datctrl.recordset_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter_slice;
import webtank.ivy.datctrl.deserialize;

class RecordSetAdapter: IClassNode
{
	alias TDataNode = DataNode!string;
private:
	TDataNode _rawRS;
	size_t[string] _namesMapping;

public:
	this(TDataNode rawRS)
	{
		_rawRS = rawRS;
		_ensureRecordSet();

		foreach( i, fmt; _rawFormat.array )
		{
			assert( "n" in fmt, `Expected name field "n" in record raw format` );
			_namesMapping[ fmt["n"].str ] = i;
		}

		foreach( i, ref recData; _rawData.array )
		{
			foreach( j, ref fieldData; recData.array ) {
				_deserializeFieldInplace(fieldData, _rawFormat[j]);
			}
		}
	}

	void _ensureRecordSet()
	{
		assert( "t" in _rawRS, `Expected type field "t" in recordset raw data!` );
		assert( "d" in _rawRS, `Expected data field "d" in recordset raw data!` );
		assert( "f" in _rawRS, `Expected format field "f" in recordset raw data!` );
		assert( _rawRS["t"].type == DataNodeType.String && _rawRS["t"].str == "recordset", `Expected "recordset" value in "t" field` );
	}

	TDataNode _rawData() @property {
		return _rawRS["d"];
	}

	TDataNode _rawFormat() @property {
		return _rawRS["f"];
	}

	static class Range: IDataNodeRange
	{
	private:
		RecordSetAdapter _rs;
		size_t i = 0;

	public:
		this(RecordSetAdapter recordSet) {
			_rs = recordSet;
		}

		override {
			bool empty() @property
			{
				import std.range: empty;
				return i >= _rs._rawData.array.length;
			}

			TDataNode front() {
				return _rs._makeRecord(i);
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

	private TDataNode _makeRecord(size_t index)
	{
		import std.conv: text;
		assert( index < _rawData.array.length, `No record with index ` ~ index.text ~ ` in record set!` );
		return TDataNode(new RecordAdapter(
			TDataNode([
				"d": _rawData.array[index],
				"f": _rawFormat,
				"t": TDataNode("record")
			]),
			_namesMapping
		));
	}

	override IDataNodeRange opSlice() {
		return new Range(this);
	}

	override RecordSetAdapterSlice opSlice(size_t begin, size_t end) {
		return new RecordSetAdapterSlice(this, begin, end);
	}

	override TDataNode opIndex(size_t index) {
		return _makeRecord(index);
	}

	override TDataNode opIndex(string key) {
		assert(false, `Indexing by string key is not supported for RecordSetAdapter`);
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

	override void __setAttr__(TDataNode node, string attrName) {
		assert(false, `Not attributes setting is yet supported by RecordSetAdapter`);
	}

	override TDataNode __serialize__() {
		// Maybe we should make deep copy of it there, but because of productivity
		// we shall not do it now. Just say for now that nobody should modifiy serialized data
		return _rawRS;
	}

	override size_t length() @property {
		return _rawData.array.length;
	}

	TDataNode serializeSlice(size_t begin, size_t end)
	{
		TDataNode result;
		
		if( _rawRS.type == DataNodeType.AssocArray )
		foreach( string key, TDataNode val; _rawRS.assocArray )
		{
			if( key != "d" ) {
				result[key] = val;
			} else if( val.type == DataNodeType.Array ) {
				result[key] = val.array[begin..end];
			}
		}
		return result;
	}
}