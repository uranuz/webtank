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
	this(IBaseWriteableDataField[] dataFields, size_t keyFieldIndex = 0)
	{
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

	import webtank.datctrl.common;
	mixin GetStdJSONFormatImpl;
	mixin GetStdJSONDataImpl;

	override {
		IBaseWriteableDataField getField(string fieldName)
		{
			import std.exception: enforce;
			enforce(fieldName in _fieldIndexes, `There is no field with name "` ~ fieldName ~ `" in detatched record`);
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

		bool isWriteable(string fieldName) {
			return getField(fieldName).isWriteable;
		}

		size_t length() @property {
			return _dataFields.length;
		}

		void nullify(string fieldName) {
			getField(fieldName).nullify(recordIndex);
		}

		JSONValue toStdJSON()
		{
			import webtank.datctrl.consts: SrlField, SrlEntityType;
			auto jValues = this.getStdJSONFormat();
			jValues[SrlField.data] = this.getStdJSONData(recordIndex);
			jValues[SrlField.type] = SrlEntityType.record;
			return jValues;
		}

		size_t keyFieldIndex() @property {
			return _keyFieldIndex;
		}
	} // override

	import std.json: JSONValue, JSONType;
	static DetatchedRecord fromStdJSONByFormat(RecordFormatT)(JSONValue jRecord, RecordFormatT format)
	{
		import webtank.datctrl.memory_data_field: makeMemoryDataFields;
		import webtank.datctrl.common: _extractFromJSON, _makeRecordFieldIndex;

		JSONValue jFormat;
		JSONValue jData;
		string type;
		Optional!size_t kfi;

		_extractFromJSON(jRecord, jFormat, jData, type, kfi);

		enforce(type == SrlEntityType.record, `Expected record type`);

		// Fill with init format for now
		IBaseWriteableDataField[] dataFields = makeMemoryDataFields(format);

		auto newRec = new DetatchedRecord(dataFields, RecordFormatT.getKeyFieldIndex!());
		newRS.addItems(1); // Add exactly on field

		size_t[string] fieldToIndex = _makeRecordFieldIndex(jFormat);

		_fillDataIntoRec!(RecordFormatT)(dataFields, jRecord, 0, fieldToIndex);

		return newRec; // Hope we have done there
	}

	static DetatchedRecord fromStdJSON(JSONValue jRecord)
	{
		import std.algorithm: canFind;
		import std.exception: enforce;
		import std.conv: to;

		import webtank.datctrl.memory_data_field: makeMemoryDataFieldsDyn;
		import webtank.datctrl.common: _extractFromJSON;
		import webtank.common.optional: Optional;
		import webtank.datctrl.consts: SrlEntityType;

		JSONValue jFormat;
		JSONValue jData;
		string type;
		Optional!size_t kfi;

		_extractFromJSON(jRecord, jFormat, jData, type, kfi);

		enforce(kfi.isSet, `Expected key field index`);
		enforce(type == SrlEntityType.record, `Expected recordset type`);

		IBaseWriteableDataField[] dataFields = makeMemoryDataFieldsDyn(jFormat, JSONValue([jData]));
		auto newRec = new DetatchedRecord(dataFields, kfi.value);

		return newRec;
	}
}

auto makeMemoryRecord(RecordFormatT)(RecordFormatT format)
{
	import webtank.datctrl.memory_data_field;
	import webtank.datctrl.typed_record;
	return TypedRecord!(RecordFormatT, DetatchedRecord)(
		new DetatchedRecord(
			makeMemoryDataFields(format),
			RecordFormatT.getKeyFieldIndex!()
		)
	);
}