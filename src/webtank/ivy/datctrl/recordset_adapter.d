module webtank.ivy.datctrl.recordset_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter_slice;

import webtank.ivy.datctrl.record_format_adapter: RecordFormatAdapter;

import std.exception: enforce;

class RecordSetAdapter: IClassNode
{
private:
	RecordAdapter[] _items;
	RecordFormatAdapter _fmt;

public:
	this(IvyData rawRS)
	{
		_ensureRecordSet(rawRS);
		_fmt = new RecordFormatAdapter(rawRS);

		import webtank.ivy.datctrl.deserialize: _deserializeRecordData;
		IvyData rawItems = rawRS["d"];
		foreach( i, ref recData; rawItems.array )
		{
			IvyData[] recordData;
			foreach( j, ref fieldData; recData.array ) {
				recordData ~= _deserializeRecordData(fieldData, _fmt[IvyData(j)]);
			}
			_items ~= new RecordAdapter(_fmt, recordData);
		}
	}

	void _ensureRecordSet(IvyData rawRS)
	{
		enforce("t" in rawRS, `Expected type field "t" in recordset raw data!`);
		enforce("d" in rawRS, `Expected data field "d" in recordset raw data!`);
		enforce(rawRS["d"].type == IvyDataType.Array, `Data field "d" expected to be array`);
		enforce("f" in rawRS, `Expected format field "f" in recordset raw data!`);
		enforce(
			rawRS["t"].type == IvyDataType.String && rawRS["t"].str == "recordset",
			`Expected "recordset" value in "t" field`
		);
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
				return i >= _rs._items.length;
			}

			IvyData front() {
				return IvyData(_rs._getRecord(i));
			}

			void popFront() {
				++i;
			}
		}
	}

	private RecordAdapter _getRecord(size_t index)
	{
		import std.conv: text;
		enforce(index < _items.length, `No record with index ` ~ index.text ~ ` in record set!`);
		return _items[index];
	}

	override {
		IvyNodeRange opSlice() {
			return new Range(this);
		}

		RecordSetAdapterSlice opSlice(size_t begin, size_t end) {
			return new RecordSetAdapterSlice(this, begin, end);
		}

		IvyData opIndex(IvyData index)
		{
			import std.conv: text;
			switch( index.type )
			{
				case IvyDataType.Integer: {
					return IvyData(_getRecord(index.integer));
				}
				default: break;
			}
			throw new Exception(`Unexpected kind of index argument: ` ~ index.type.text);
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
			throw new Exception(`Not attributes setting is yet supported by RecordSetAdapter`);
		}

		IvyData __serialize__()
		{
			IvyData res = _fmt.__serialize__();
			res["t"] = "recordset";

			IvyData[] itemsData;
			foreach( record; _items ) {
				itemsData ~= record._serializeData();
			}
			res["d"] = itemsData;
			
			return res;
		}

		size_t length() @property {
			return _items.length;
		}
	}

	IvyData serializeSlice(size_t begin, size_t end)
	{
		IvyData res = _fmt.__serialize__();
		res["t"] = "recordset";

		IvyData[] itemsData;
		foreach( record; _items[begin..end] ) {
			itemsData ~= record._serializeData();
		}
		res["d"] = itemsData;
		
		return res;
	}
}