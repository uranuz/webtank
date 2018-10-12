module webtank.ivy.datctrl.recordset_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter_slice;
import webtank.ivy.datctrl.deserialize;

import webtank.ivy.datctrl.record_format_adapter: RecordFormatAdapter;

import std.exception: enforce;

class RecordSetAdapter: IClassNode
{
private:
	IvyData _rawRS;
	RecordFormatAdapter _fmt;

public:
	this(IvyData rawRS)
	{
		_rawRS = rawRS;
		_ensureRecordSet();
		_fmt = new RecordFormatAdapter(rawRS);

		foreach( i, ref recData; _rawData.array )
		{
			foreach( j, ref fieldData; recData.array ) {
				_deserializeFieldInplace(fieldData, _fmt[j]);
			}
		}
	}

	void _ensureRecordSet()
	{
		enforce("t" in _rawRS, `Expected type field "t" in recordset raw data!`);
		enforce("d" in _rawRS, `Expected data field "d" in recordset raw data!`);
		enforce("f" in _rawRS, `Expected format field "f" in recordset raw data!`);
		enforce(
			_rawRS["t"].type == IvyDataType.String && _rawRS["t"].str == "recordset",
			`Expected "recordset" value in "t" field`
		);
	}

	IvyData _rawData() @property {
		return _rawRS["d"];
	}

	static class Range: IvyNodeRange
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

			IvyData front() {
				return _rs._makeRecord(i);
			}

			void popFront() {
				++i;
			}
		}
	}

	private IvyData _makeRecord(size_t index)
	{
		import std.conv: text;
		assert( index < _rawData.array.length, `No record with index ` ~ index.text ~ ` in record set!` );
		return IvyData(new RecordAdapter(
			IvyData([
				"d": _rawData.array[index],
				"f": _rawRS["f"],
				"t": IvyData("record")
			]),
			_fmt
		));
	}

	override {
		IvyNodeRange opSlice() {
			return new Range(this);
		}

		RecordSetAdapterSlice opSlice(size_t begin, size_t end) {
			return new RecordSetAdapterSlice(this, begin, end);
		}

		IvyData opIndex(size_t index) {
			return _makeRecord(index);
		}

		IvyData opIndex(string key) {
			assert(false, `Indexing by string key is not supported for RecordSetAdapter`);
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

		void __setAttr__(IvyData node, string attrName) {
			assert(false, `Not attributes setting is yet supported by RecordSetAdapter`);
		}

		IvyData __serialize__() {
			// Maybe we should make deep copy of it there, but because of productivity
			// we shall not do it now. Just say for now that nobody should modifiy serialized data
			return _rawRS;
		}

		size_t length() @property {
			return _rawData.length;
		}
	}

	IvyData serializeSlice(size_t begin, size_t end)
	{
		IvyData result;
		
		if( _rawRS.type == IvyDataType.AssocArray )
		foreach( string key, IvyData val; _rawRS.assocArray )
		{
			if( key != "d" ) {
				result[key] = val;
			} else if( val.type == IvyDataType.Array ) {
				result[key] = val.array[begin..end];
			}
		}
		return result;
	}
}