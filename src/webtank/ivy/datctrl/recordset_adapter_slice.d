module webtank.ivy.datctrl.recordset_adapter_slice;

import ivy.types.data.decl_class_node: DeclClassNode;

class RecordSetAdapterSlice: DeclClassNode
{
	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.data.iface.range: IvyDataRange;
	import ivy.interpreter.directive.base: IvyMethodAttr;
	import ivy.types.data.decl_class: DeclClass;

	import webtank.ivy.datctrl.recordset_adapter: RecordSetAdapter;

private:
	RecordSetAdapter _rs;
	size_t _begin;
	size_t _end;

public:
	this(RecordSetAdapter rs, size_t begin, size_t end)
	{
		super(_declClass);

		if( rs is null )
			throw new Exception("Wrong input for RecordSetAdapterSlice");

		this._rs = rs;
		this._begin = begin;
		this._end = end;

		if( this._begin > this._rs.length ) {
			this._begin = rs.length;
		}
		if( this._end > this._rs.length ) {
			this._end = rs.length;
		}
		if( this._begin > this._end ) {
			this._begin = this._end;
		}
	}

	static class Range: IvyDataRange
	{
	private:
		RecordSetAdapterSlice _rs;
		size_t i = 0;

	public:
		this(RecordSetAdapterSlice recordSet) {
			this._rs = recordSet;
		}

		override {
			bool empty() @property {
				return i >= this._rs.length;
			}

			IvyData front() {
				return this._rs[IvyData(i)];
			}

			void popFront() {
				++i;
			}
		}
	}

	private void _testIndex(size_t index)
	{
		if( index >= length )
			throw new Exception("RecordSetAdapterSlice index is out of range");
	}

	override IvyDataRange opSlice() {
		return new Range(this);
	}

	override IvyData opIndex(IvyData index)
	{
		import std.conv: text;
		import std.exception: enforce;
		switch( index.type )
		{
			case IvyDataType.Integer: {
				_testIndex(index.integer);
				return this._rs[IvyData(index.integer + _begin)];
			}
			default: break;
		}
		throw new Exception("Unexpected kind of index argument: " ~ index.type.text);
	}

	override IvyData __getAttr__(string attrName) {
		return this._rs.__getAttr__(attrName);
	}

	override size_t length() @property {
		return this._end - this._begin;
	}

	@IvyMethodAttr()
	IvyData __serialize__() {
		return this._rs.serializeSlice(this._begin, this._end);
	}

	// Initialized in webtank.ivy.datctrl._recordset_init because of circular dependencies
	package __gshared DeclClass _declClass;
}