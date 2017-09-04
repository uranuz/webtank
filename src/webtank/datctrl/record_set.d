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
	import webtank.datctrl.cursor_record: CursorRecord;
protected:
	IBaseDataField[] _dataFields;
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
		IBaseDataField keyField = _dataFields[_keyFieldIndex];
		_recordIndexes.clear();
		foreach( i; 0 .. keyField.length )
		{
			auto keyValue = keyField.getStr(i);
			assert(keyValue !in _recordIndexes, `Record key must be unique!`);
			_recordIndexes[keyValue] = i;
		}
	}

public:
	this(IBaseDataField[] dataFields, size_t keyFieldIndex)
	{
		_dataFields = dataFields;
		_reindexFields();
		_reindexRecords();
	}
	
	IBaseDataField getField(string fieldName) {
		assert(fieldName in _fieldIndexes, `Field doesn't exist in recordset!`);
		return _dataFields[ _fieldIndexes[fieldName] ];
	}

	RecordType opIndex(size_t recordIndex) {
		return getRecord(recordIndex);
	}

	RecordType getRecord(size_t recordIndex) {
		return new CursorRecord(this, recordIndex);
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
		return ( _dataFields.length > 0 ) ? _dataFields[0].length : 0;
	}

	size_t fieldCount() @property {
		return dataFields.length;
	}

	JSONValue getStdJSONData(size_t index)
	{
		JSONValue[] recJSON;
		recJSON.length = _dataFields.length;
		foreach( i, dataField; _dataFields ) {
			recJSON[i] = dataField.getStdJSONValue(i);
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

	IRecordSetRange opSlice() {
		return new Range(this);
	}

	size_t getIndexByStringKey(string recordKey) {
		return _dataFields[recordKey];
	}

	static class Range: InputRange!IBaseRecord
	{
		private IBaseRecordSet _rs;
		private size_t _index = 0;

		this(IBaseRecordSet rs) {
			_rs = rs;
		}

		public override {
			bool empty() @property {
				return _index < _rs.length;
			}

			RecordType front() @property {
				return _rs.getRecord(_index);
			}

			void popFront() {
				_index++;
			}
		}
	}

}
