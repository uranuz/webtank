module webtank.ivy.datctrl.recordset_adapter_slice;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter;
import webtank.ivy.datctrl.deserialize;

class RecordSetAdapterSlice: IClassNode
{
	alias TDataNode = DataNode!string;
private:
	RecordSetAdapter _rs;
	size_t _begin;
	size_t _end;

public:
	this(RecordSetAdapter rs, size_t begin, size_t end)
	{
		if( rs is null || begin > rs.length || end > rs.length || begin > end )
			throw new Exception(`Wrong input for RecordSetAdapterSlice`);

		_rs = rs;
		_begin = begin;
		_end = end;
	}

	static class Range: IDataNodeRange
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

			TDataNode front() {
				return _rs[i];
			}

			void popFront() {
				++i;
			}

			DataNodeType aggrType() @property {
				return DataNodeType.Array;
			}
		}
	}

	private void _testIndex(size_t index)
	{
		if( index >= length )
			throw new Exception(`RecordSetAdapterSlice index is out of range`);
	}

	override IDataNodeRange opSlice() {
		return new Range(this);
	}

	override RecordSetAdapter opSlice(size_t, size_t) {
		assert(false, `Getting slice for RecordSetAdapterSlice is not supported yet`);
	}

	override TDataNode opIndex(size_t index) {
		_testIndex(index);
		return _rs[index + _begin];
	}

	override TDataNode opIndex(string key) {
		assert(false, `Indexing by string key is not supported for RecordSetAdapterSlice`);
	}

	override TDataNode __getAttr__(string attrName) {
		return _rs.__getAttr__(attrName);
	}

	override void __setAttr__(TDataNode node, string attrName) {
		assert(false, `Not attributes setting is yet supported by RecordSetAdapterSlice`);
	}

	override TDataNode __serialize__() {
		return _rs.serializeSlice(_begin, _end);
	}

	size_t length() @property {
		return _end - _begin;
	}
}