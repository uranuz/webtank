module webtank.ivy.datctrl.record_format_adapter;

import ivy, ivy.compiler.compiler;
import ivy.interpreter.interpreter;
import ivy.interpreter.data_node;

import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;
import webtank.ivy.datctrl.field_format_adapter: FieldFormatAdapter;

class RecordFormatAdapter: NotImplClassNode
{
	import webtank.datctrl.consts;
	import std.exception: enforce;
private:
	IClassNode[] _items;
	size_t[string] _namesMapping;
	size_t _keyFieldIndex = 0;

public:
	this(IvyData rawData)
	{
		enforce(rawData.type == IvyDataType.AssocArray, `Record format raw data must be object`);
		auto fmtPtr = SrlField.format in rawData;
		enforce(fmtPtr, `Expected format field "` ~ SrlField.format ~ `" in record raw data!`);
		enforce(fmtPtr.type == IvyDataType.Array, `Format field "` ~ SrlField.format ~ `" expected to be array`);

		foreach( i, fmt; fmtPtr.array )
		{
			enforce(fmt.type == IvyDataType.AssocArray, `Expected assoc array as field format raw data`);

			auto namePtr = SrlField.name in fmt;
			auto typePtr = SrlField.type in fmt;
			enforce(namePtr, `Expected name field "` ~ SrlField.name ~ `" for field in raw record format`);
			enforce(typePtr, `Expected type field "` ~ SrlField.type ~ `" for field in raw record format`);

			_namesMapping[namePtr.str] = i;
			if( typePtr.str == SrlField.enum_ ) {
				_items ~= new EnumFormatAdapter(fmt);
			} else {
				_items ~= new FieldFormatAdapter(fmt);
			}
		}
		if( auto keyFieldIndexPtr = SrlField.keyFieldIndex in rawData.assocArray )
		{
			enforce(keyFieldIndexPtr.type == IvyDataType.Integer, `Key field index field expected to be integer`);
			_keyFieldIndex = keyFieldIndexPtr.integer;
		}
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
				return _fmt[IvyData(i)];
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

		IvyData opIndex(IvyData index)
		{
			import std.conv: text;
			switch( index.type )
			{
				case IvyDataType.Integer: {
					enforce(index.integer < _items.length, `Record format column with index ` ~ index.integer.text ~ ` is not found!`);
					return IvyData(_items[index.integer]);
				}
				case IvyDataType.String: {
					enforce(index.str in _namesMapping, `Record format column with name "` ~ index.str ~ `" is not found!`);
					return IvyData(_items[ _namesMapping[index.str] ]);
				}
				default: break;
			}
			throw new Exception(`Unexpected kind of index argument: ` ~ index.type.text);
		}

		IvyData __getAttr__(string attrName)
		{
			return IvyData();
		}

		IvyData __serialize__()
		{
			IvyData[] formats;
			foreach( fmt; _items ) {
				formats ~= fmt.__serialize__();
			}

			return IvyData([
				SrlField.format: IvyData(formats),
				SrlField.keyFieldIndex: IvyData(_keyFieldIndex)
			]);
		}

		size_t length() @property {
			return _items.length;
		}
	}
}