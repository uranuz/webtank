module webtank.ivy.datctrl.recordset_adapter;

import ivy.types.data.decl_class_node: DeclClassNode;

class RecordSetAdapter: DeclClassNode
{
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.data.iface.range: IvyDataRange;
	import ivy.interpreter.directive.utils: IvyMethodAttr;
	import ivy.types.data.decl_class: DeclClass;

	import webtank.datctrl.consts: SrlField, SrlEntityType;
	import webtank.ivy.datctrl.record_format_adapter: RecordFormatAdapter;
	import webtank.ivy.datctrl.record_adapter: RecordAdapter;
	import webtank.ivy.datctrl.recordset_adapter_slice: RecordSetAdapterSlice;

	import std.exception: enforce;
private:
	RecordFormatAdapter _fmt;
	RecordAdapter[] _items;

public:
	this(IvyData rawRS)
	{
		super(_declClass);

		auto typePtr = SrlField.type in rawRS;
		auto dataPtr = SrlField.data in rawRS;
		auto fmtPtr = SrlField.format in rawRS;
		
		enforce(typePtr, `Expected type field "` ~ SrlField.type ~ `" in recordset raw data!`);
		enforce(dataPtr, `Expected data field "` ~ SrlField.data ~ `" in recordset raw data!`);
		enforce(dataPtr.type == IvyDataType.Array, `Data field "` ~ SrlField.data ~ `" expected to be array`);
		enforce(fmtPtr, `Expected format field "` ~ SrlField.format ~ `" in recordset raw data!`);
		enforce(
			typePtr.type == IvyDataType.String && typePtr.str == SrlEntityType.recordSet,
			`Expected "` ~ SrlEntityType.recordSet ~ `" value in "` ~ SrlField.format ~ `" field`);

		this._fmt = new RecordFormatAdapter(rawRS);

		import webtank.ivy.datctrl.deserialize.record_data: _deserializeRecordData;
		foreach( i, ref recData; dataPtr.array )
			this._items ~= new RecordAdapter(this._fmt, _deserializeRecordData(recData, this._fmt));
	}

	static class Range: IvyDataRange
	{
	private:
		RecordSetAdapter _rs;
		size_t i = 0;

	public:
		this(RecordSetAdapter recordSet) {
			this._rs = recordSet;
		}

		override {
			bool empty() @property
			{
				import std.range: empty;
				return i >= this._rs._items.length;
			}

			IvyData front() {
				return IvyData(this._rs._getRecord(i));
			}

			void popFront() {
				++i;
			}
		}
	}

	private RecordAdapter _getRecord(size_t index)
	{
		import std.conv: text;
		enforce(index < this._items.length, `No record with index ` ~ index.text ~ ` in record set!`);
		return this._items[index];
	}

	override {
		IvyDataRange opSlice() {
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

		size_t length() @property {
			return this._items.length;
		}
	}

	IvyData serializeSlice(size_t begin, size_t end) {
		return this._serializeItems(this._items[begin..end]);
	}

	@IvyMethodAttr()
	IvyData __serialize__() {
		return this._serializeItems(this._items);
	}

	private IvyData _serializeItems(RecordAdapter[] items)
	{
		IvyData res = this._fmt.__serialize__();
		res[SrlField.type] = SrlEntityType.recordSet;

		IvyData[] itemsData;
		foreach( record; items ) {
			itemsData ~= record._serializeData();
		}
		res[SrlField.data] = itemsData;
		
		return res;
	}

	// Initialized in webtank.ivy.datctrl._recordset_init because of circular dependencies
	package __gshared DeclClass _declClass;
}