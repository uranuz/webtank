module webtank.ivy.datctrl.record_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;

import webtank.ivy.datctrl.record_format_adapter: RecordFormatAdapter;
import webtank.ivy.datctrl.enum_adapter: EnumAdapter;

import std.exception: enforce;

class RecordAdapter: IClassNode
{
private:
	IvyData[] _items;
	RecordFormatAdapter _fmt;

public:
	this(IvyData rawRec)
	{
		_ensureRecord(rawRec);
		_fmt = new RecordFormatAdapter(rawRec);
		_items = _deserialize(rawRec);
	}


	this(RecordFormatAdapter fmt, IvyData[] items)
	{
		enforce(fmt !is null, `Expected record format adapter`);
		enforce(items.length == fmt.length, `Number of field in record format must match number of items in record data`);
		_fmt = fmt;
		_items = items;
	}

	static void _ensureRecord(IvyData rawRec)
	{
		enforce("t" in rawRec, `Expected type field "t" in record raw data!`);
		enforce("d" in rawRec, `Expected data field "d" in record raw data!`);
		enforce(rawRec["d"].type == IvyDataType.Array, `Data field "d" expected to be array`);
		enforce("f" in rawRec, `Expected format field "f" in record raw data!`);
		enforce(
			rawRec["t"].type == IvyDataType.String && rawRec["t"].str == "record",
			`Expected "record" value in "t" field`
		);
	}

	IvyData[] _deserialize(IvyData rawRec)
	{
		import webtank.ivy.datctrl.deserialize: _deserializeRecordData;
		IvyData rawItems = rawRec["d"];
		IvyData[] res;
		foreach( i, ref fieldData; rawItems.array ) {
			res ~= _deserializeRecordData(fieldData, _fmt[IvyData(i)]);
		}
		return res;
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
				return i >= _rec._items.length;
			}

			IvyData front() {
				return _rec._items[i];
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
			throw new Exception(`opSlice for RecordAdapter is not implemented yet`);
		}

		IvyData opIndex(IvyData index)
		{
			import std.conv: text;
			switch( index.type )
			{
				case IvyDataType.Integer: {
					enforce(index.integer < _items.length, `Record column with index ` ~ index.integer.text ~ ` is not found!`);
					return _items[index.integer];
				}
				case IvyDataType.String: {
					enforce(index.str in _fmt.namesMapping, `Record column with name "` ~ index.str ~ `" is not found!`);
					return _items[ _fmt.namesMapping[index.str] ];
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
			return this[IvyData(attrName)];
		}

		void __setAttr__(IvyData value, string attrName) {
			enforce(false, `Not attributes setting is yet supported by RecordAdapter`);
		}

		IvyData __serialize__()
		{
			IvyData res = _fmt.__serialize__();
			res["d"] = _serializeData();
			res["t"] = "record";

			return res;
		}

		size_t length() @property {
			return _fmt.length;
		}
	}

	IvyData _serializeData()
	{
		IvyData[] data;
		foreach( value; _items ) {
			if( value.type == IvyDataType.ClassNode ) {
				if( value.classNode is null ) {
					data ~= IvyData(null);
				} else if ( EnumAdapter maybeEnum = cast(EnumAdapter) value.classNode ) {
					data ~= maybeEnum.__getAttr__("value");
				} else {
					data ~= value.classNode.__serialize__();
				}
			} else {
				data ~= value;
			}
		}

		return IvyData(data);
	}
}