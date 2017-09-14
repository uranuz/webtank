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

	import std.json: JSONValue;
	JSONValue getStdJSONData(size_t index)
	{
		JSONValue[] recJSON;
		recJSON.length = _dataFields.length;
		foreach( i, dataField; _dataFields ) {
			recJSON[i] = dataField.getStdJSONValue(index);
		}
		return JSONValue(recJSON);
	}

	JSONValue getStdJSONFormat()
	{
		JSONValue jValues;
		jValues["kfi"] = _keyFieldIndex; // Номер ключевого поля
		jValues["t"] = "recordset"; // Тип данных - набор записей

		//Образуем JSON-массив форматов полей
		JSONValue[] jFieldFormats;
		jFieldFormats.length = _dataFields.length;

		foreach( i, field; _dataFields ) {
			jFieldFormats[i] = field.getStdJSONFormat();
		}
		jValues["f"] = jFieldFormats;

		return jValues;
	}

	JSONValue toStdJSON()
	{
		auto jValues = this.getStdJSONFormat();

		JSONValue[] jData;
		jData.length = this.length;

		foreach( i; 0..this.length ) {
			jData[i] = this.getStdJSONData(i);
		}

		jValues["d"] = jData;

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

	static class Range: RangeIface
	{
		private RecordSetIface _rs;
		private size_t _index = 0;

		this(RecordSetIface rs) {
			_rs = rs;
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
				int opApply(scope int delegate(IBaseRecord))
				{
					assert(false, `Not implemented yet!`);
				}

				int opApply(scope int delegate(ulong, IBaseRecord))
				{
					assert(false, `Not implemented yet!`);
				}
			}

			int opApply(scope int delegate(RecordIface))
			{
				assert(false, `Not implemented yet!`);
			}

			int opApply(scope int delegate(ulong, RecordIface))
			{
				assert(false, `Not implemented yet!`);
			}
		}
	}
}
