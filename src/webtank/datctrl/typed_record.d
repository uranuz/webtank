module webtank.datctrl.typed_record;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.iface.record;
import webtank.datctrl.record_format;

// Обёртка над классом записи для обеспечения интерфейса доступа к данным со статической проверкой типа
struct TypedRecord(RecordFormatT, RecordType)
{
	// Тип формата для записи
	alias FormatType = RecordFormatT;
	private RecordType _record;

	this(RecordType record) {
		_record = record;
	}

	template _getTypedField(string fieldName, bool isWriteable = false)
	{
		import webtank.datctrl.iface.data_field;
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
		static if( isWriteable ) {
			alias DataFieldType = IWriteableDataField!FieldFormatType;
		} else {
			alias DataFieldType = IDataField!FieldFormatType;
		}

		DataFieldType _getTypedField()
		{
			DataFieldType dataField = cast(DataFieldType) _record.getField(fieldName);
			assert(dataField, `Failed to cast data field to target type or field is null`);
			return dataField;
		}
	}

	template get(string fieldName)
	{	
		alias ValueType = FormatType.getValueType!(fieldName);

		/++
		$(LOCALE_EN_US Function for getting value for field with name $(D_PARAM fieldName).
			If field value is null then behaviour is undefined
		)
		$(LOCALE_RU_RU Функция получения значения для поля с именем $(D_PARAM fieldName).
			При пустом значении поля поведение не определено
		)
		+/
		ValueType get() {
			return _getTypedField!(fieldName).get(_record.recordIndex);
		}

		/++
		$(LOCALE_EN_US Function for getting value for field with name $(D_PARAM fieldName).
			Parameter $(D_PARAM defaultValue) determines returned value if value
			for field with name $(D_PARAM fieldName) is null
		)
		$(LOCALE_RU_RU Функция получения значения для поля с именем $(D_PARAM fieldName).
			Параметр $(D_PARAM defaultValue) определяет возвращаемое значение,
			если значение для поля с именем $(D_PARAM fieldName) является пустым (null)
		)
		+/
		ValueType get(ValueType defaultValue) {
			return _getTypedField!(fieldName).get(_record.recordIndex, defaultValue);
		}
	}
	
	template getStr(string fieldName)
	{
		static assert(RecordFormatT.hasField!(fieldName), `Record doesn't contain field with name "` ~ fieldName ~ `"!!!`);

		string getStr() {
			return _record.getStr(fieldName);
		}

		string getStr(string defaultValue) {
			return _record.getStr(fieldName, defaultValue);
		}
	}
	
	/++
	$(LOCALE_EN_US Method returns format for enumerated field with name $(D_PARAM fieldName).
		If field $(D_PARAM fieldName) is not enumerated this will not compile
	)
	$(LOCALE_RU_RU Метод возвращает формат для перечислимого поля с именем $(D_PARAM fieldName).
		Если поле $(D_PARAM fieldName) не является перечислимым, то это породит ошибку компиляции
	)
	+/
	template getEnumFormat(string fieldName)
	{
		auto getEnumFormat() {
			return _getTypedField!(fieldName).enumFormat;
		}
	}

	template set(string fieldName)
	{
		alias ValueType = FormatType.getValueType!(fieldName);

		void set(ValueType value) {
			_getTypedField!(fieldName, true).set(value, _record.recordIndex);
		}
	}

	public auto record() @property {
		return _record;
	}

	alias record this;
}

import webtank.datctrl.detatched_record;
import webtank.datctrl.memory_data_field;

unittest {
	auto recFormat = RecordFormat!(
		PrimaryKey!(size_t), "num",
		string, "name"
	)();
	IBaseWriteableDataField[] dataFields = makeMemoryDataFields(recFormat);
	auto baseRec = new DetatchedRecord(dataFields);
	auto rec = TypedRecord!(typeof(recFormat), IBaseWriteableRecord)(baseRec);
	assert(rec.isNull("name"));
	rec.set!"name"("test");
	assert(rec.get!"name"() == "test");
	assert(!rec.isNull("name"));
}