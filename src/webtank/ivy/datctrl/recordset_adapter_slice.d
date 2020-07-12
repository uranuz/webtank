module webtank.ivy.datctrl.recordset_adapter_slice;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter;
import webtank.ivy.datctrl.deserialize;

class RecordSetAdapterSlice: NotImplClassNode
{
private:
	RecordSetAdapter _rs;
	size_t _begin;
	size_t _end;

public:
	this(RecordSetAdapter rs, size_t begin, size_t end)
	{
		if( rs is null )
			throw new Exception(`Wrong input for RecordSetAdapterSlice`);

		_rs = rs;
		_begin = begin;
		_end = end;

		if( _begin > _rs.length ) {
			_begin = rs.length;
		}
		if( _end > _rs.length ) {
			_end = rs.length;
		}
		if( _begin > _end ) {
			_begin = _end;
		}
	}

	static class Range: IvyNodeRange
	{
	private:
		RecordSetAdapterSlice _rs;
		size_t i = 0;

	public:
		this(RecordSetAdapterSlice recordSet) {
			_rs = recordSet;
		}

		override {
			bool empty() @property {
				return i >= _rs.length;
			}

			IvyData front() {
				return _rs[IvyData(i)];
			}

			void popFront() {
				++i;
			}
		}
	}

	private void _testIndex(size_t index)
	{
		if( index >= length )
			throw new Exception(`RecordSetAdapterSlice index is out of range`);
	}

	override IvyNodeRange opSlice() {
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
				return _rs[IvyData(index.integer + _begin)];
			}
			default: break;
		}
		throw new Exception(`Unexpected kind of index argument: ` ~ index.type.text);
	}

	override IvyData __getAttr__(string attrName) {
		return _rs.__getAttr__(attrName);
	}

	override IvyData __serialize__() {
		return _rs.serializeSlice(_begin, _end);
	}

	override size_t length() @property {
		return _end - _begin;
	}
}