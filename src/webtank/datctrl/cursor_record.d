module webtank.datctrl.cursor_record;

import webtank.datctrl.iface.data_field: IBaseDataField, IBaseWriteableDataField;
import webtank.datctrl.iface.record: IBaseRecord, IBaseWriteableRecord;
import webtank.datctrl.iface.record_set: IBaseRecordSet, IBaseWriteableRecordSet;

/++
$(LANG_EN Class implements working with record)
$(LANG_RU Класс реализует работу с записью)
+/
class CursorRecord: IBaseRecord
{
	mixin CursorRecordImpl!false;
}

class WriteableCursorRecord: IBaseWriteableRecord
{
	mixin CursorRecordImpl!true;
public:
	override {
		void nullify(string fieldName) {
			_recordSet.nullify(fieldName, recordIndex);
		}
		void setNullable(string fieldName, bool value) {
			_recordSet.setNullable(fieldName, value);
		}
	}
}

mixin template CursorRecordImpl(bool isWriteableFlag)
{
	static if( isWriteableFlag )
	{
		alias RecordSetIface = IBaseWriteableRecordSet;
		alias DataFieldIface = IBaseWriteableDataField;
	}
	else
	{
		alias RecordSetIface = IBaseRecordSet;
		alias DataFieldIface = IBaseDataField;
	}
protected:
	RecordSetIface _recordSet;
	string _recordKey;

public:
	this(RecordSetIface recordSet, string recordKey)
	{
		import std.exception: enforce;
		enforce(recordSet !is null, `Expected record set, but got null!`);
		_recordSet = recordSet;
		_recordKey = recordKey;
	}

	override {
		size_t recordIndex() @property {
			return _recordSet.getIndexByStringKey(_recordKey);
		}

		DataFieldIface getField(string fieldName) {
			return _recordSet.getField(fieldName);
		}

		string getStr(string fieldName) {
			return _recordSet.getStr(fieldName, recordIndex);
		}

		string getStr(string fieldName, string defaultValue) {
			return _recordSet.getStr(fieldName, recordIndex, defaultValue);
		}

		bool isNull(string fieldName) {
			return _recordSet.isNull(fieldName, recordIndex);
		}

		bool isNullable(string fieldName) {
			return _recordSet.isNullable(fieldName);
		}

		bool isWriteable(string fieldName) {
			return _recordSet.isWriteable(fieldName);
		}

		size_t length() @property {
			return _recordSet.fieldCount;
		}

		import std.json: JSONValue;
		JSONValue toStdJSON()
		{
			JSONValue jValues = _recordSet.getStdJSONFormat();
			jValues["d"] = _recordSet.getStdJSONData(recordIndex);
			jValues["t"] = "record";
			return jValues;
		}

		size_t keyFieldIndex() @property {
			return _recordSet.keyFieldIndex();
		}
	} //override
}

unittest
{
	IBaseRecordSet rs;
	auto rec = new CursorRecord(rs, "0");
}