module webtank.ivy.datctrl.recordset_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter_slice;

import webtank.ivy.datctrl.record_format_adapter: RecordFormatAdapter;

import std.exception: enforce;

import webtank.datctrl.consts;

class RecordSetAdapter: IClassNode
{
private:
	RecordAdapter[] _items;
	RecordFormatAdapter _fmt;

public:
	this(IvyData rawRS)
	{
		auto typePtr = WT_TYPE_FIELD in rawRS;
		auto dataPtr = WT_DATA_FIELD in rawRS;
		auto fmtPtr = WT_FORMAT_FIELD in rawRS;
		
		enforce(typePtr, `Expected type field "` ~ WT_TYPE_FIELD ~ `" in recordset raw data!`);
		enforce(dataPtr, `Expected data field "` ~ WT_DATA_FIELD ~ `" in recordset raw data!`);
		enforce(dataPtr.type == IvyDataType.Array, `Data field "` ~ WT_DATA_FIELD ~ `" expected to be array`);
		enforce(fmtPtr, `Expected format field "` ~ WT_FORMAT_FIELD ~ `" in recordset raw data!`);
		enforce(
			typePtr.type == IvyDataType.String && typePtr.str == WT_TYPE_RECORDSET,
			`Expected "` ~ WT_TYPE_RECORDSET ~ `" value in "` ~ WT_FORMAT_FIELD ~ `" field`);

		_fmt = new RecordFormatAdapter(rawRS);

		import webtank.ivy.datctrl.deserialize: _deserializeRecordData;
		foreach( i, ref recData; dataPtr.array )
		{
			IvyData[] recordData;
			foreach( j, ref fieldData; recData.array ) {
				recordData ~= _deserializeRecordData(fieldData, _fmt[IvyData(j)]);
			}
			_items ~= new RecordAdapter(_fmt, recordData);
		}
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
			res[WT_TYPE_FIELD] = WT_TYPE_RECORDSET;

			IvyData[] itemsData;
			foreach( record; _items ) {
				itemsData ~= record._serializeData();
			}
			res[WT_DATA_FIELD] = itemsData;
			
			return res;
		}

		size_t length() @property {
			return _items.length;
		}
	}

	IvyData serializeSlice(size_t begin, size_t end)
	{
		IvyData res = _fmt.__serialize__();
		res[WT_TYPE_FIELD] = WT_TYPE_RECORDSET;

		IvyData[] itemsData;
		foreach( record; _items[begin..end] ) {
			itemsData ~= record._serializeData();
		}
		res[WT_DATA_FIELD] = itemsData;
		
		return res;
	}
}