module webtank.datctrl.record_set;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.iface.record;
import webtank.datctrl.iface.record_set;
import webtank.datctrl.record_set_slice;


/++
$(LANG_EN Class implements work with record set)
$(LANG_RU Класс реализует работу с набором записей)
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
			_reindexRecords(); // Reindex after adding new items
		}

		void addItems(IBaseWriteableRecord[] records, size_t index = size_t.max)
		{
			import std.exception: enforce;
			enforce(false, `Not implemented yet!!!`);
		}
	}

	import std.json: JSONValue, JSON_TYPE;
	static WriteableRecordSet fromStdJSONByFormat(RecordFormatT)(JSONValue jRecordSet)
	{
		import std.exception: enforce;
		enforce(jRecordSet.type == JSON_TYPE.OBJECT, `Expected JSON object as RecordSet serialized data!!!`);
		enforce(`t` in jRecordSet, `Expected "t" field in RecordSet serialized data!!!`);
		enforce(`d` in jRecordSet, `Expected "d" field in RecordSet serialized data!!!`);
		enforce(`f` in jRecordSet, `Expected "f" field in RecordSet serialized data!!!`);
		JSONValue jFormat = jRecordSet[`f`];
		JSONValue jData = jRecordSet[`d`];
		enforce(jData.type == JSON_TYPE.ARRAY, `RecordSet serialized data field "d" must be JSON array!!!`);
		enforce(jFormat.type == JSON_TYPE.ARRAY, `RecordSet serialized data field "f" must be JSON array!!!`);
		

		size_t[string] fieldToIndex;
		foreach( size_t index, JSONValue jField; jFormat )
		{
			enforce(jField.type == JSON_TYPE.OBJECT, `RecordSet serialized field format must be object!!!`);
			enforce(`n` in jField, `RecordSet serialized field format must have "n" field`);
			enforce(jField[`n`].type == JSON_TYPE.STRING, `RecordSet serialized field name must be JSON string!!!`);
			string fieldName = jField[`n`].str;
			enforce(fieldName !in fieldToIndex, `RecordSet field name must be unique!!!`);
			fieldToIndex[fieldName] = index;
		}

		import webtank.datctrl.memory_data_field: makeMemoryDataFields;
		IBaseWriteableDataField[] dataFields = makeMemoryDataFields(RecordFormatT.init); // Fill with init format for now

		auto newRS = new WriteableRecordSet(dataFields, RecordFormatT.getKeyFieldIndex!());
		newRS.addItems(jData.array.length); // Expand fields to desired size

		enum size_t expectedFieldCount = RecordFormatT.tupleOfNames.length;
		import std.conv: text;
		foreach( size_t recIndex, JSONValue jRecord; jData )
		{
			enforce(jRecord.type == JSON_TYPE.ARRAY, `Record serialized data expected to be JSON array!!!`);
			enforce(jRecord.array.length >= expectedFieldCount,
				`Not enough items in serialized Record. Expected ` ~ expectedFieldCount.text ~ ` got ` ~ jRecord.array.length.text);
			foreach( formatFieldIndex, name; RecordFormatT.names )
			{
				enforce(name in fieldToIndex, `Expected field in recordset with name: ` ~ name);
				dataFields[formatFieldIndex].fromStdJSONValue(jRecord[fieldToIndex[name]], recIndex);
			}
		}

		newRS._reindexFields();
		newRS._reindexRecords();
		return newRS; // Hope we have done there
	}
}

mixin template RecordSetImpl(bool isWriteableFlag)
{
protected:
	import std.range.interfaces: InputRange;
	import std.exception: enforce;
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
			enforce(dataField.name !in _fieldIndexes, `Data field name must be unique!`);
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
			enforce(keyValue !in _recordIndexes, `Record key "` ~ keyValue ~ `" is not unique!`);
			_recordIndexes[keyValue] = i;
		}
	}

public:
	this(DataFieldIface[] dataFields, size_t keyFieldIndex = 0)
	{
		enforce(keyFieldIndex < dataFields.length, `Key field index is out of bounds of data field list`);
		_dataFields = dataFields;
		_keyFieldIndex = keyFieldIndex;
		_reindexFields();
		_reindexRecords();
	}

	override {
		DataFieldIface getField(string fieldName)
		{
			enforce(fieldName in _fieldIndexes, `Field doesn't exist in recordset!`);
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
		mixin RecordSetToStdJSONImpl;

		RangeIface opSlice() {
			return new Range(this);
		}

		IBaseRecordSet opSlice(size_t begin, size_t end) {
			return new RecordSetSlice(this, begin, end);
		}

		size_t getIndexByStringKey(string recordKey)
		{
			enforce(recordKey in _recordIndexes, `Cannot find record with specified key!`);
			return _recordIndexes[recordKey];
		}
	} // override

	import webtank.datctrl.record_set_range;
	mixin RecordSetRangeImpl;
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