module webtank.ivy.datctrl.enum_format_adapter;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.interpreter.data_node;
import webtank.ivy.datctrl.deserialize;

import std.exception: enforce;

import webtank.datctrl.consts;

class EnumFormatAdapter: IClassNode
{
private:
	IvyData _rawEnum;
	NameByValue _names;
	ValueByName _values;

public:
	this(IvyData rawEnum)
	{
		_rawEnum = rawEnum;

		auto typePtr = SrlField.type in _rawEnum;
		auto enumPtr = SrlField.enum_ in _rawEnum;

		enforce(typePtr, `Expected type field "` ~ SrlField.type ~ `" in enum raw data!`);
		enforce(enumPtr, `Expected "` ~ SrlField.enum_ ~ `" field in enum raw data!`);
		enforce(
			typePtr.type == IvyDataType.String && typePtr.str == SrlEntityType.enum_,
			`Expected "` ~ SrlEntityType.enum_ ~ `" value in "` ~ SrlField.type ~ `" field`);
		enforce(_rawItems.type == IvyDataType.Array, `Expected array as enum items`);

		_names = new NameByValue(this);
		_values = new ValueByName(this);
	}

	IvyData _rawItems() @property {
		return _rawEnum[SrlField.enum_];
	}

	NameByValue names() @property {
		return _names;
	}

	ValueByName values() @property {
		return _values;
	}

	bool hasValue(IvyData index)
	{
		foreach( item; _rawItems.array )
		{
			enforce(item.type == IvyDataType.Array, `Raw enum item data is not assoc array`);
			enforce(item.array.length > 0, `Expected at least 1 element in enum item`);
			if( item.array[0] == index ) {
				return true;
			}
		}
		return false;
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
				res["value"] = item.array[0];
				if( item.array.length > 1 ) {
					res["name"] = item.array[1];
				}
				return res;
			}

			void popFront() {
				++i;
			}
		}
	}

	static class NameByValue: IClassNode
	{
		protected EnumFormatAdapter _fmt;

		this(EnumFormatAdapter fmt) {
			_fmt = fmt;
		}
		
		override {
			IvyNodeRange opSlice() {
				throw new Exception(`opSlice for EnumFormatAdapter.NameByValue is not implemented yet`);
			}
			IClassNode opSlice(size_t, size_t) {
				throw new Exception(`opSlice for EnumFormatAdapter.NameByValue is not implemented yet`);
			}
			IvyData opIndex(IvyData index)
			{
				import std.conv: text;
				import std.algorithm: canFind;
				foreach( item; _fmt._rawItems.array )
				{
					enforce(item.type == IvyDataType.Array, `Raw enum item data is not assoc array`);
					enforce(item.array.length > 1, `Expected at least 2 elements in enum item`);
					if( item.array[0] == index ) {
						return item.array[1];
					}
				}
				if( [IvyDataType.Undef, IvyDataType.Null].canFind(index.type) ) {
					return index;
				}
				throw new Exception(`There is no item with value: "` ~ index.toString() ~ `" in enum`);
			}
			IvyData __getAttr__(string) {
				throw new Exception(`__getAttr__ for EnumFormatAdapter.NameByValue is not implemented yet`);
			}
			void __setAttr__(IvyData, string) {
				throw new Exception(`__setAttr__ for EnumFormatAdapter.NameByValue is not implemented yet`);
			}
			IvyData __serialize__() {
				throw new Exception(`__serialize__ for EnumFormatAdapter.NameByValue is not implemented yet`);
			}
			size_t length() @property {
				throw new Exception(`length for EnumFormatAdapter.NameByValue is not implemented yet`);
			}
		}
	}

	static class ValueByName: IClassNode
	{
		protected EnumFormatAdapter _fmt;

		this(EnumFormatAdapter fmt) {
			_fmt = fmt;
		}
		
		override {
			IvyNodeRange opSlice() {
				throw new Exception(`opSlice for EnumFormatAdapter.ValueByName is not implemented yet`);
			}
			IClassNode opSlice(size_t, size_t) {
				throw new Exception(`opSlice for EnumFormatAdapter.ValueByName is not implemented yet`);
			}
			IvyData opIndex(IvyData index)
			{
				import std.conv: text;
				import std.algorithm: canFind;
				foreach( item; _fmt._rawItems.array )
				{
					enforce(item.type == IvyDataType.Array, `Raw enum item data is not assoc array`);
					enforce(item.array.length > 1, `Expected at least 2 elements in enum item`);
					if( item.array[1] == index ) {
						return item.array[0];
					}
				}
				if( [IvyDataType.Undef, IvyDataType.Null].canFind(index.type) ) {
					return index;
				}
				throw new Exception(`There is no item with value: "` ~ index.toString() ~ `" in enum`);
			}
			IvyData __getAttr__(string) {
				throw new Exception(`__getAttr__ for EnumFormatAdapter.ValueByName is not implemented yet`);
			}
			void __setAttr__(IvyData, string) {
				throw new Exception(`__setAttr__ for EnumFormatAdapter.ValueByName is not implemented yet`);
			}
			IvyData __serialize__() {
				throw new Exception(`__serialize__ for EnumFormatAdapter.ValueByName is not implemented yet`);
			}
			size_t length() @property {
				throw new Exception(`length for EnumFormatAdapter.ValueByName is not implemented yet`);
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
			import std.conv: to;
			enforce(index.type == IvyDataType.Integer, `Expected integer as index, but got: ` ~ index.to!string);
			return _rawItems.array[index.integer];
		}

		IvyData __getAttr__(string attrName)
		{
			switch( attrName )
			{
				case "names":
					return IvyData(_names);
				case "values":
					return IvyData(_values);
				default: break;
			}
			throw new Exception(`Unexpected attribute for EnumFormatAdapter`);
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