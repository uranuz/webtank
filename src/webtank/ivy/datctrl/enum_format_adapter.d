module webtank.ivy.datctrl.enum_format_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.deserialize;

import std.exception: enforce;

class EnumFormatAdapter: IClassNode
{
private:
	IvyData _rawEnum;

public:
	this(IvyData rawEnum)
	{
		_rawEnum = rawEnum;
		_ensureEnum();
	}

	void _ensureEnum()
	{
		enforce("t" in _rawEnum, `Expected type field "t" in enum raw data!`);
		enforce("enum" in _rawEnum, `Expected "enum" field in enum raw data!`);
		enforce(
			_rawEnum["t"].type == IvyDataType.String && _rawEnum["t"].str == "enum",
			`Expected "enum" value in "t" field`
		);
		enforce(_rawItems.type == IvyDataType.Array, `Expected array as enum items`);
	}

	IvyData _rawItems() @property {
		return _rawEnum["enum"];
	}

	static class Range: IvyNodeRange
	{
	private:
		EnumFormatAdapter _fmt;
		size_t i = 0;

	public:
		this(EnumFormatAdapter fmt) {
			_fmt = fmt;
		}

		override {
			bool empty() @property
			{
				import std.range: empty;
				return i >= _fmt._rawItems.length;
			}

			IvyData front()
			{
				IvyData item = _fmt._rawItems[i];
				enforce(item.type == IvyDataType.Array, `Raw enum item data is not array`);
				enforce(item.array.length > 0, `Expected at least 1 elements in enum item`);
				IvyData res;
				res["value"] = item[0];
				if( item.array.length > 1 ) {
					res["name"] = item[1];
				}
				return res;
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
			throw new Exception(`opSlice for EnumFormatAdapter is not implemented yet`);
		}

		IvyData opIndex(IvyData index)
		{
			import std.conv: text;
			foreach( item; _rawItems.array )
			{
				enforce(item.type == IvyDataType.AssocArray, `Raw enum item data is not assoc array`);
				enforce(item.array.length > 1, `Expected at least 2 elements in enum item`);
				if( item.array[0] == index ) {
					return item.array[1];
				}
			}
			throw new Exception(`There is no item with value: "` ~ index.toString() ~ `" in enum`);
		}

		IvyData __getAttr__(string attrName) {
			throw new Exception(`Not attributes getting is yet supported by EnumFormatAdapter`);
		}

		void __setAttr__(IvyData value, string attrName) {
			throw new Exception(`Not attributes setting is yet supported by EnumFormatAdapter`);
		}

		IvyData __serialize__() {
			// Maybe we should make deep copy of it there, but because of productivity
			// we shall not do it now. Just say for now that nobody should modifiy serialized data
			return _rawEnum;
		}

		size_t length() @property {
			return _rawItems.length;
		}
	}

	
}