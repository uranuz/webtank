module webtank.ivy.datctrl.record_format_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;

import std.exception: enforce;
import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;
import webtank.ivy.datctrl.field_format_adapter: FieldFormatAdapter;

class RecordFormatAdapter: IClassNode
{
private:
	IClassNode[] _items;
	size_t[string] _namesMapping;
	size_t _keyFieldIndex = 0;

public:
	this(IvyData rawData)
	{
		enforce(rawData.type == IvyDataType.AssocArray, `Record format raw data must be object`);
		enforce("f" in rawData, `Expected format field "f" in record raw data!`);
		enforce(rawData["f"].type == IvyDataType.Array, `Format field "d" expected to be array`);

		IvyData rawItems = rawData["f"];
		foreach( i, fmt; rawItems.array )
		{
			enforce(fmt.type == IvyDataType.AssocArray, `Expected assoc array as field format raw data`);
			enforce("n" in fmt, `Expected name field "n" for field in raw record format`);
			enforce("t" in fmt, `Expected type field "t" for field in raw record format`);
			_namesMapping[ fmt["n"].str ] = i;
			if( fmt["t"].str == "enum" ) {
				_items ~= new EnumFormatAdapter(fmt);
			} else {
				_items ~= new FieldFormatAdapter(fmt);
			}
		}
		if( auto keyFieldIndexPtr = "kfi" in rawData.assocArray )
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

		IClassNode opSlice(size_t, size_t) {
			throw new Exception(`opSlice for RecordFormatAdapter is not implemented yet`);
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

		void __setAttr__(IvyData value, string attrName) {
			enforce(false, `No attributes setting is yet supported by RecordFormatAdapter`);
		}

		IvyData __serialize__()
		{
			IvyData[] formats;
			foreach( fmt; _items ) {
				formats ~= fmt.__serialize__();
			}

			return IvyData([
				"f": IvyData(formats),
				"kfi": IvyData(_keyFieldIndex)
			]);
		}

		size_t length() @property {
			return _items.length;
		}
	}
}