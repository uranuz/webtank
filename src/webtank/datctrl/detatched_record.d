module webtank.datctrl.detatched_record;

import webtank.datctrl.iface.record;
import webtank.datctrl.iface.data_field;

class DetatchedRecord: IBaseWriteableRecord
{
protected:
	IBaseWriteableDataField[] _dataFields;
	size_t _keyFieldIndex;
	size_t[string] _fieldIndexes;

public:
	this(IBaseWriteableDataField[] dataFields, size_t keyFieldIndex = 0) {
		_dataFields = dataFields;
		_keyFieldIndex = keyFieldIndex;
		foreach( dataField; _dataFields )
		{
			// Требуется наличие хотя бы одного элемента в каждом из полей данных
			if ( dataField.length == 0) {
				dataField.addItems(1);
			}
		}
		_reindex();
	}

	private void _reindex()
	{
		_fieldIndexes.clear();
		foreach( i, dataField; _dataFields ) {
			_fieldIndexes[dataField.name] = i;
		}
	}

	override {
		IBaseWriteableDataField getField(string fieldName)
		{
			assert(fieldName in _fieldIndexes);
			return _dataFields[ _fieldIndexes[fieldName] ];
		}

		size_t recordIndex() @property {
			return 0; // Предполагаем, что в полях отдельной записи только один первый элемент
		}

		string getStr(string fieldName) {
			return getField(fieldName).getStr(recordIndex);
		}

		string getStr(string fieldName, string defaultValue) {
			return getField(fieldName).getStr(recordIndex, defaultValue);
		}

		bool isNull(string fieldName) {
			return getField(fieldName).isNull(recordIndex);
		}

		bool isNullable(string fieldName) {
			return getField(fieldName).isNullable;
		}
		
		bool isWriteable(string fieldName) {
			return getField(fieldName).isWriteable;
		}
		
		size_t length() @property {
			return _dataFields.length;
		}

		void nullify(string fieldName) {
			getField(fieldName).nullify(recordIndex);
		}

		void setNullable(string fieldName, bool value) {
			getField(fieldName).isNullable = value;
		}

		import std.json: JSONValue;

		JSONValue toStdJSON()
		{
			assert(false, `Not implemented yet!`);
		}

		size_t keyFieldIndex() @property {
			return _keyFieldIndex;
		}
	} // override
}
