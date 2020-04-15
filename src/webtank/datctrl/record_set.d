module webtank.datctrl.record_set;

import webtank.datctrl.iface.record_set: IBaseRecordSet, IBaseWriteableRecordSet;

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

	import webtank.datctrl.iface.data_field: IBaseWriteableDataField;

public:
	IBaseWriteableDataField getWriteableField(string fieldName) {
		return _assureWriteable(getField(fieldName));
	}

	IBaseWriteableDataField _assureWriteable(DataFieldIface field)
	{
		auto wrField = cast(IBaseWriteableDataField) field;
		enforce(wrField !is null, `Field with name "` ~ field.name ~ `" is not writeable`);
		return wrField;
	}

	override {
		void nullify(string fieldName, size_t recordIndex) {
			getWriteableField(fieldName).nullify(recordIndex);
		}

		void setNullable(string fieldName, bool value) {
			getWriteableField(fieldName).isNullable = value;
		}

		void addItems(size_t count, size_t index = size_t.max)
		{
			import std.array: insertInPlace;

			if( index == size_t.max ) {
				index = this.length? this.length - 1: 0;
			}

			foreach( dataField; _dataFields ) {
				_assureWriteable(dataField).addItems(count, index);
			}

			RecordType[] newCursors;
			foreach( i; 0..count ) {
				newCursors ~= new RecordType(this);
			}

			_cursors.insertInPlace(index, newCursors);

			_reindexRecords(); // Reindex after adding new items
		}

		void addItems(IBaseWriteableRecord[] records, size_t index = size_t.max)
		{
			import std.exception: enforce;
			enforce(false, `Not implemented yet!!!`);
		}
	}

	import std.json: JSONValue, JSONType;
	static WriteableRecordSet fromStdJSONByFormat(RecordFormatT)(JSONValue jRecordSet)
	{
		import std.exception: enforce;
		import std.conv: text;
		import webtank.datctrl.memory_data_field: makeMemoryDataFields;
		import webtank.datctrl.common: _makeRecordFieldIndex, _extractFromJSON, _fillDataIntoRec;
		import webtank.common.optional: Optional;
		import webtank.datctrl.consts: SrlEntityType;


		JSONValue jFormat;
		JSONValue jData;
		string type;
		Optional!size_t kfi;

		_extractFromJSON(jRecordSet, jFormat, jData, type, kfi);
		enforce(type == SrlEntityType.recordSet, `Expected recordset type`);

		size_t[string] fieldToIndex = _makeRecordFieldIndex(jFormat);

		// Fill with init format for now
		IBaseWriteableDataField[] dataFields = makeMemoryDataFields(RecordFormatT.init);

		auto newRS = new WriteableRecordSet(dataFields, RecordFormatT.getKeyFieldIndex!());
		newRS.addItems(jData.array.length); // Expand fields to desired size

		foreach( size_t recIndex, JSONValue jRecord; jData ) {
			_fillDataIntoRec!(RecordFormatT)(dataFields, jRecord, recIndex, fieldToIndex);
		}

		newRS._reindexFields();
		newRS._reindexRecords();
		return newRS; // Hope we have done there
	}

	static WriteableRecordSet fromStdJSON(JSONValue jRecordSet)
	{
		import std.algorithm: canFind;
		import std.conv: to;

		import webtank.datctrl.memory_data_field: makeMemoryDataFieldsDyn;
		import webtank.datctrl.common: _extractFromJSON;
		import webtank.common.optional: Optional;
		import webtank.datctrl.consts: SrlEntityType;

		JSONValue jFormat;
		JSONValue jData;
		string type;
		Optional!size_t kfi;

		_extractFromJSON(jRecordSet, jFormat, jData, type, kfi);

		enforce(kfi.isSet, `Expected key field index`);
		enforce(type == SrlEntityType.recordSet, `Expected recordset type`);

		IBaseWriteableDataField[] dataFields = makeMemoryDataFieldsDyn(jFormat, jData);
		auto newRS = new WriteableRecordSet(dataFields, kfi.value);

		newRS._reindexFields();
		newRS._reindexRecords();
		return newRS;
	}
}

mixin template RecordSetImpl(bool isWriteableFlag)
{
protected:
	import std.exception: enforce;

	import webtank.datctrl.iface.record: IBaseRecord;
	import webtank.datctrl.iface.data_field: IBaseDataField;
	static if( isWriteableFlag )
	{
		import webtank.datctrl.cursor_record: WriteableCursorRecord;
		import webtank.datctrl.iface.record: IBaseWriteableRecord;
		import webtank.datctrl.iface.data_field: IBaseWriteableDataField;
		import webtank.datctrl.iface.record_set: IWriteableRecordSetRange;
		alias RecordSetIface = IBaseWriteableRecordSet;
		alias DataFieldIface = IBaseDataField;
		alias RangeIface = IWriteableRecordSetRange;
		alias RecordIface = IBaseWriteableRecord;
		alias RecordType = WriteableCursorRecord;
	}
	else
	{
		import webtank.datctrl.cursor_record: CursorRecord;
		import webtank.datctrl.iface.record_set: IRecordSetRange;
		alias RecordSetIface = IBaseRecordSet;
		alias DataFieldIface = IBaseDataField;
		alias RangeIface = IRecordSetRange;
		alias RecordIface = IBaseRecord;
		alias RecordType = CursorRecord;
	}

	DataFieldIface[] _dataFields;
	size_t _keyFieldIndex;
	size_t[string] _recordIndexes;
	size_t[string] _fieldIndexes;

	RecordType[] _cursors;
	size_t[RecordType] _cursorIndexes;

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
		_cursorIndexes.clear();
		foreach( i; 0 .. keyField.length )
		{
			auto keyValue = keyField.getStr(i);
			if( !keyField.isNull(i) ) {
				// Костыль: если добавили несколько пустых записей с помощью addItems,
				// то не ругаемся на неуникальность по пустому ключу
				enforce(keyValue !in _recordIndexes, `Record key "` ~ keyValue ~ `" is not unique!`);
			}

			if( keyValue !in _recordIndexes ) {
				// Хотим, чтобы по пустому ключу была первая запись из пустых
				_recordIndexes[keyValue] = i;
			}
		}

		// Индексируем курсоры
		foreach( i, curs; _cursors ) {
			_cursorIndexes[curs] = i;
		}
	}

	void _initCursors()
	{
		// Создаем курсоры. При этом при каждом получении записи будет физически один и тот же курсор
		foreach( i; 0..this.length ) {
			_cursors ~= new RecordType(this);
		}
	}

public:
	this(DataFieldIface[] dataFields, size_t keyFieldIndex = 0)
	{
		enforce(keyFieldIndex < dataFields.length, `Key field index is out of bounds of data field list`);
		_dataFields = dataFields;
		_keyFieldIndex = keyFieldIndex;
		_reindexFields();
		_initCursors();
		_reindexRecords();
	}

	static if( isWriteableFlag )
	{
		this(IBaseWriteableDataField[] dataFields, size_t keyFieldIndex = 0) {
			this(cast(DataFieldIface[]) dataFields, keyFieldIndex);
		}
	}

	override {
		DataFieldIface getField(string fieldName)
		{
			enforce(fieldName in _fieldIndexes, `Field doesn't exist in recordset!`);
			return _dataFields[ _fieldIndexes[fieldName] ];
		}

		RecordIface opIndex(size_t recordIndex) {
			return getRecordAt(recordIndex);
		}

		RecordIface getRecordAt(size_t recordIndex)
		{
			import std.exception: enforce;
			enforce(recordIndex < _cursors.length, `No record with specified index in record set`);

			return _cursors[recordIndex];
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

		size_t length() @property inout {
			return ( _dataFields.length > 0 )? _dataFields[0].length : 0;
		}

		size_t fieldCount() @property inout {
			return _dataFields.length;
		}

		import webtank.datctrl.common;
		mixin GetStdJSONFormatImpl;
		mixin GetStdJSONDataImpl;
		mixin RecordSetToStdJSONImpl;

		RangeIface opSlice() {
			return new Range(this);
		}

		IBaseRecordSet opSlice(size_t begin, size_t end)
		{
			import webtank.datctrl.record_set_slice: RecordSetSlice;
			return new RecordSetSlice(this, begin, end);
		}

		size_t getIndexByStringKey(string recordKey)
		{
			enforce(recordKey in _recordIndexes, `Cannot find record with specified key!`);
			return _recordIndexes[recordKey];
		}

		size_t getIndexByCursor(IBaseRecord cursor)
		{
			RecordType typedCursor = cast(RecordType) cursor;
			enforce(typedCursor, `Record type mismatch`);
			enforce(typedCursor in _cursorIndexes, `Cannot get index in record set for specified record`);
			return _cursorIndexes[typedCursor];
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