module webtank.ivy.datctrl.record_adapter;

import ivy.types.data.decl_class_node: DeclClassNode;

class RecordAdapter: DeclClassNode
{
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.data.iface.range: IvyDataRange;
	import ivy.interpreter.directive.utils: IvyMethodAttr;
	import ivy.types.data.decl_class: DeclClass;
	import ivy.types.data.decl_class_utils: makeClass;

	import webtank.datctrl.consts: SrlField, SrlEntityType;
	import webtank.ivy.datctrl.record_format_adapter: RecordFormatAdapter;
	import webtank.ivy.datctrl.enum_adapter: EnumAdapter;

	import std.exception: enforce;

private:
	IvyData[] _items;
	RecordFormatAdapter _fmt;

public:
	this(IvyData rawRec)
	{
		import webtank.ivy.datctrl.deserialize.record_data: _deserializeRecordData;
		super(_declClass);

		auto typePtr = SrlField.type in rawRec;
		auto dataPtr = SrlField.data in rawRec;
		auto fmtPtr = SrlField.format in rawRec;

		enforce(typePtr, `Expected type field "` ~ SrlField.type ~ `" in record raw data!`);
		enforce(dataPtr, `Expected data field "` ~ SrlField.data ~ `" in record raw data!`);
		enforce(dataPtr.type == IvyDataType.Array, `Data field "` ~ SrlField.data ~ `" expected to be array`);
		enforce(fmtPtr, `Expected format field "` ~ SrlField.format ~ `" in record raw data!`);
		enforce(
			typePtr.type == IvyDataType.String && typePtr.str == SrlEntityType.record,
			`Expected "` ~ SrlEntityType.record ~ `" value in "` ~ SrlField.type ~ `" field`);
	
		this._fmt = new RecordFormatAdapter(rawRec);
		this._items = _deserializeRecordData(*dataPtr, this._fmt);
	}

	this(RecordFormatAdapter fmt, IvyData[] items)
	{
		super(_declClass);

		enforce(fmt !is null, `Expected record format adapter`);
		enforce(items.length == fmt.length, `Number of field in record format must match number of items in record data`);
		_fmt = fmt;
		_items = items;
	}

	static class Range: IvyDataRange
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
		IvyDataRange opSlice() {
			return new Range(this);
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
					data ~= IvyData(null); // value.classNode.__serialize__();
				}
			} else {
				data ~= value;
			}
		}

		return IvyData(data);
	}

	@IvyMethodAttr()
	IvyData __serialize__()
	{
		IvyData res = _fmt.__serialize__();
		res[SrlField.data] = _serializeData();
		res[SrlField.type] = SrlEntityType.record;

		return res;
	}

	private __gshared DeclClass _declClass;

	shared static this()
	{
		_declClass = makeClass!(typeof(this))("RecordAdapter");
	}
}