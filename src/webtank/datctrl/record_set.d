module webtank.datctrl.record_set;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.iface.record;
import webtank.datctrl.iface.record_set;


/++
$(LOCALE_EN_US Class implements work with record set)
$(LOCALE_RU_RU Класс реализует работу с набором записей)
+/
class RecordSet: IBaseRecordSet
{
	mixin RecordSetImpl!false;
}

class WriteableRecordSet: IBaseWriteableRecordSet
{
	mixin RecordSetImpl!true;

public:
	override {
		void nullify(string fieldName, size_t recordIndex) {
			getField(fieldName).nullify(recordIndex);
		}

		void setNullable(string fieldName, bool value) {
			getField(fieldName).isNullable = value;
		}

		void addItems(size_t count, size_t index = size_t.max)
		{
			foreach( dataField; _dataFields ) {
				dataField.addItems(count, index);
			}
		}

		void addItems(IBaseWriteableRecord[] records, size_t index = size_t.max) {
			assert(false);
		}
	}
}

mixin template RecordSetImpl(bool isWriteableFlag)
{
protected:
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

	DataFieldIface[] _dataFields;
	size_t _keyFieldIndex;
	size_t[string] _recordIndexes;
	size_t[string] _fieldIndexes;

	void _reindexFields()
	{
		_fieldIndexes.clear();
		foreach( i, dataField; _dataFields )
		{
			assert(dataField.name !in _fieldIndexes, `Data field name must be unique!`);
			_fieldIndexes[dataField.name] = i;
		}
	}

	void _reindexRecords()
	{
		DataFieldIface keyField = _dataFields[_keyFieldIndex];
		_recordIndexes.clear();
		foreach( i; 0 .. keyField.length )
		{
			auto keyValue = keyField.getStr(i);
			assert(keyValue !in _recordIndexes, `Record key must be unique!`);
			_recordIndexes[keyValue] = i;
		}
	}

public:
	this(DataFieldIface[] dataFields, size_t keyFieldIndex = 0)
	{
		_dataFields = dataFields;
		_keyFieldIndex = keyFieldIndex;
		_reindexFields();
		_reindexRecords();
	}

	override {
		DataFieldIface getField(string fieldName)
		{
			assert(fieldName in _fieldIndexes, `Field doesn't exist in recordset!`);
			return _dataFields[ _fieldIndexes[fieldName] ];
		}

		RecordIface opIndex(size_t recordIndex) {
			return getRecord(recordIndex);
		}

		RecordIface getRecord(size_t recordIndex)
		{
			import std.conv: to;
			return new RecordType(this, _dataFields[_keyFieldIndex].getStr(recordIndex));
		}

		string getStr(string fieldName, size_t recordIndex) {
			return getField(fieldName).getStr(recordIndex);
		}

		string getStr(string fieldName, size_t recordIndex, string defaultValue) {
			return getField(fieldName).getStr(recordIndex, defaultValue);
		}

		size_t keyFieldIndex() @property {
			return _keyFieldIndex;
		}

		bool isNull(string fieldName, size_t recordIndex) {
			return getField(fieldName).isNull(recordIndex);
		}

		bool isNullable(string fieldName) {
			return getField(fieldName).isNullable;
		}

		bool isWriteable(string fieldName) {
			return getField(fieldName).isWriteable;
		}

		size_t length() @property {
			return ( _dataFields.length > 0 )? _dataFields[0].length : 0;
		}

		size_t fieldCount() @property {
			return _dataFields.length;
		}

		import webtank.datctrl.common;
		mixin GetStdJSONFormatImpl;
		mixin GetStdJSONDataImpl;

		import std.json: JSONValue;
		JSONValue toStdJSON()
		{
			auto jValues = this.getStdJSONFormat();

			JSONValue[] jData;
			jData.length = this.length;

			foreach( i; 0..this.length ) {
				jData[i] = this.getStdJSONData(i);
			}

			jValues["d"] = jData;
			jValues["t"] = "recordset";

			return jValues;
		}

		RangeIface opSlice() {
			return new Range(this);
		}

		size_t getIndexByStringKey(string recordKey)
		{
			assert(recordKey in _recordIndexes, `Cannot find record with specified key!`);
			return _recordIndexes[recordKey];
		}
	} // override

	static class Range: RangeIface
	{
		private RecordSetIface _rs;
		private size_t _index = 0;

		this(RecordSetIface rs) {
			_rs = rs;
		}

		template _opApplyImpl(Rec, bool withIndex)
		{
			static if( withIndex ) {
				alias DelegateType = scope int delegate(size_t, Rec);
			} else {
				alias DelegateType = scope int delegate(Rec);
			}

			int _opApplyImpl(DelegateType dg)
			{
				int result = 0;
				foreach( i; 0.._rs.length )
				{
					static if( withIndex ) {
						result = dg(i, _rs.getRecord(i));
					} else {
						result = dg(_rs.getRecord(i));
					}
					if (result)
						break;
				}
				return result;
			}
		}

		public override {
			bool empty() @property {
				return _index < _rs.length;
			}

			RecordIface front() @property {
				return _rs.getRecord(_index);
			}

			RecordIface moveFront() {
				assert(false, `Not implemented yet!`);
			}

			void popFront() {
				_index++;
			}

			static if( isWriteableFlag )
			{
				int opApply(scope int delegate(IBaseRecord) dg) {
					return _opApplyImpl!(IBaseRecord, false)(dg);
				}

				int opApply(scope int delegate(size_t, IBaseRecord) dg) {
					return _opApplyImpl!(IBaseRecord, true)(dg);
				}
			}

			int opApply(scope int delegate(RecordIface) dg) {
				return _opApplyImpl!(RecordIface, false)(dg);
			}

			int opApply(scope int delegate(size_t, RecordIface) dg) {
				return _opApplyImpl!(RecordIface, true)(dg);
			}
		}
	}
}

IBaseWriteableRecordSet makeMemoryRecordSet(RecordFormatT)(RecordFormatT format)
{
	import webtank.datctrl.memory_data_field;
	import webtank.datctrl.typed_record_set;
	return TypedRecordSet!(RecordFormatT, WriteableRecordSet)(
		new WriteableRecordSet(
			makeMemoryDataFields(format),
			RecordFormatT.getKeyFieldIndex!()
		)
	);
}