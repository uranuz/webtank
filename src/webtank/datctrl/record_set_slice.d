module webtank.datctrl.record_set_slice;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.iface.record;
import webtank.datctrl.iface.record_set;

class RecordSetSlice: IBaseRecordSet
{
protected:
	enum bool isWriteableFlag = false;

	import std.range.interfaces: InputRange;
	static if( isWriteableFlag )
	{
		import webtank.datctrl.cursor_record: WriteableCursorRecord;
		alias RecordSetIface = IBaseWriteableRecordSet;
		alias DataFieldIface = IBaseWriteableDataField;
		alias RangeIface = IWriteableRecordSetRange;
		alias RecordIface = IBaseWriteableRecord;
		alias RecordType = WriteableCursorRecord;
	}
	else
	{
		import webtank.datctrl.cursor_record: CursorRecord;
		alias RecordSetIface = IBaseRecordSet;
		alias DataFieldIface = IBaseDataField;
		alias RangeIface = InputRange!IBaseRecord;
		alias RecordIface = IBaseRecord;
		alias RecordType = CursorRecord;
	}

	IBaseRecordSet _sourceRS;
	size_t _begin;
	size_t _end;

public:
	this(IBaseRecordSet rs, size_t begin, size_t end)
	{
		import std.exception: enforce;
		enforce(rs !is null, `Expected record set, but got null`);
		enforce(begin <= end, `Range begin index must be not greater than end index`);
		_sourceRS = rs;
		_begin = begin;
		_end = end;
	}

	private void _testIndex(size_t recordIndex) inout
	{
		if( recordIndex >= length )
			throw new Exception(`Index is out of record`);
	}

	override {
		DataFieldIface getField(string fieldName) {
			return _sourceRS.getField(fieldName);
		}

		RecordIface opIndex(size_t recordIndex) {
			_testIndex(recordIndex);
			return _sourceRS.getRecordAt(recordIndex + _begin);
		}

		RecordIface getRecordAt(size_t recordIndex) {
			_testIndex(recordIndex);
			return _sourceRS.getRecordAt(recordIndex + _begin);
		}

		string getStr(string fieldName, size_t recordIndex) {
			_testIndex(recordIndex);
			return _sourceRS.getStr(fieldName, recordIndex + _begin);
		}

		string getStr(string fieldName, size_t recordIndex, string defaultValue) {
			_testIndex(recordIndex);
			return _sourceRS.getStr(fieldName, recordIndex + _begin, defaultValue);
		}

		size_t keyFieldIndex() @property {
			return _sourceRS.keyFieldIndex;
		}

		bool isNull(string fieldName, size_t recordIndex) {
			_testIndex(recordIndex);
			return _sourceRS.isNull(fieldName, recordIndex + _begin);
		}

		bool isWriteable(string fieldName) {
			return _sourceRS.isWriteable(fieldName);
		}

		size_t length() @property inout {
			return _end - _begin;
		}

		size_t fieldCount() @property inout {
			return _sourceRS.fieldCount;
		}

		import std.json: JSONValue;
		JSONValue getStdJSONFormat() inout {
			return _sourceRS.getStdJSONFormat();
		}

		JSONValue getStdJSONData(size_t recordIndex) inout {
			_testIndex(recordIndex);
			return _sourceRS.getStdJSONData(recordIndex + _begin);
		}

		import webtank.datctrl.common;
		mixin RecordSetToStdJSONImpl;

		RangeIface opSlice() {
			return new Range(this);
		}

		IBaseRecordSet opSlice(size_t begin, size_t end) {
			return new RecordSetSlice(this, begin, end);
		}

		size_t getIndexByStringKey(string recordKey)
		{
			size_t recordIndex = _sourceRS.getIndexByStringKey(recordKey);
			_testIndex(recordIndex);
			return recordIndex;
		}

		size_t getIndexByCursor(IBaseRecord cursor)
		{
			size_t recordIndex = _sourceRS.getIndexByCursor(cursor);
			_testIndex(recordIndex);
			return recordIndex;
		}
	} // override

	import webtank.datctrl.record_set_range;
	mixin RecordSetRangeImpl;
}