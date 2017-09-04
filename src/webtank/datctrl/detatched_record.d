module webtank.datctrl.detatched_record;

import webtank.datctrl.iface.record;
import webtank.datctrl.iface.data_field;

class DetatchedRecord: IBaseWriteableRecord
{
protected:
	IBaseWriteableDataField[] _dataFields;
	size_t[string] _fieldIndexes;

public:
	this(IBaseWriteableDataField dataFields) {
		_dataFields = dataFields;
		_reindex();
	}

	private void _reindex()
	{
		_dataFields = null;
		foreach( i, dataField; _dataFields ) {
			_dataFields[dataField.name] = i;
		}
	}

	override {
		IBaseWriteableDataField getField(string fieldName) {
			assert(fieldName in _fieldIndexes);
			return _dataCells[ _fieldIndexes[fieldName] ];
		}

		size_t recordIndex() @property {
			return 0; // Предполагаем, что в полях отдельной записи только один первый элемент
		}

		string getStr(string fieldName) {
			return getField(fieldName).getStr();
		}

		string getStr(string fieldName, string defaultValue) {
			return getField(fieldName).getStr(defaultValue);
		}

		bool isNull(string fieldName) {
			return getField(fieldName).isNull;
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
			getField(fieldName).nullify();
		}

		void setNullable(string fieldName, bool value) {
			getField(fieldName).isNullable = value;
		}
	} // override
}