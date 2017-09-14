module webtank.datctrl.typed_record_set;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.iface.record_set;
import webtank.datctrl.typed_record;

struct TypedRecordSet(FormatType, RecordSetType)
{
	enum bool hasKeyField = FormatType.hasKeyField;
	alias ThisRecordSet = TypedRecordSet!(FormatType, RecordSetType);
	alias RecordIface = typeof(_recordSet[].front());
	alias RecordType = TypedRecord!(FormatType, RecordIface);

	private RecordSetType _recordSet;

	this(RecordSetType recordSet) {
		_recordSet = recordSet;
	}

	private template _getTypedField(string fieldName, bool isWriteable = false)
	{
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
		static if( isWriteable ) {
			alias DataFieldType = IWriteableDataField!FieldFormatType;
		} else {
			alias DataFieldType = IDataField!FieldFormatType;
		}

		DataFieldType _getTypedField()
		{
			DataFieldType dataField = cast(DataFieldType) _recordSet.getField(fieldName);
			assert(dataField, `Failed to cast data field to target type or field is null`);
			return dataField;
		}
	}

	/++
	$(LOCALE_EN_US Index operator for getting record by $(D_PARAM recordIndex))
	$(LOCALE_RU_RU Оператор индексирования для получения записи по номеру $(D_PARAM recordIndex))
	+/
	RecordType opIndex(size_t recordIndex) {
		return RecordType(_recordSet[recordIndex]);
	}

	/++
	$(LOCALE_EN_US Returns record by $(D_PARAM recordIndex))
	$(LOCALE_RU_RU Возвращает запись на позиции $(D_PARAM recordIndex))
	+/
	RecordType getRecord(size_t recordIndex) {
		return RecordType(_recordSet.getRecord(recordIndex));
	}

	static if( hasKeyField )
	{
		alias PKValueType = FormatType.getKeyFieldSpec!().ValueType;
		
		/++
		$(LOCALE_EN_US Returns record by it's primary $(D_PARAM recordKey))
		$(LOCALE_RU_RU Возвращает запись по первичному ключу $(D_PARAM recordKey))
		+/
		RecordType getRecordByKey(PKValueType recordKey)
		{
			import std.conv: to;
			return RecordType( _recordSet.getRecord( getRecordIndex(recordKey) ) );
		}
		
		template getByKey(string fieldName)
		{
			alias ValueType = FormatType.getValueType!(fieldName) ;

			/++
			$(LOCALE_EN_US
				Returns value of cell with field name $(D_PARAM fieldName) and primary key
				value $(D_PARAM recordKey). If cell value is null then behaviour is undefined
			)
			$(LOCALE_RU_RU
				Возвращает значение ячейки с именем поля $(D_PARAM fieldName) и значением
				первичного ключа $(D_PARAM recordKey). Если значение ячейки пустое (null), то
				поведение не определено
			)
			+/
			ValueType getByKey(PKValueType recordKey) {
				return _getTypedField!fieldName.get(getRecordIndex(recordKey));
			}

			/++
			$(LOCALE_EN_US
				Returns value of cell with field name $(D_PARAM fieldName) and primary key
				value $(D_PARAM recordKey). Parameter $(D_PARAM defaultValue) determines return
				value when cell in null
			)
			$(LOCALE_RU_RU
				Возвращает значение ячейки с именем поля $(D_PARAM fieldName) и значением
				первичного ключа $(D_PARAM recordKey). Параметр $(D_PARAM defaultValue)
				определяет возвращаемое значение, когда значение ячейки пустое (null)
			)
			+/
			ValueType getByKey(PKValueType recordKey, ValueType defaultValue) {
				return _getTypedField!fieldName.get(getRecordIndex(recordKey), defaultValue);
			}
		}
	
		string getStrByKey(string fieldName, PKValueType recordKey) {
			return _recordSet.getStr(fieldName, getRecordIndex(recordKey));
		}
		
		/++
		$(LOCALE_EN_US
			Returns string representation of cell with field name $(D_PARAM fieldName)
			and record primary key $(D_PARAM recordKey). If value of cell is empty then
			it return value specified by $(D_PARAM defaultValue) parameter, which will
			have null value if parameter is missed.
		)
		$(LOCALE_RU_RU
			Возвращает строковое представление ячейки с именем поля $(D_PARAM fieldName)
			и значением первичного ключа записи $(D_PARAM recordKey). Если значение
			ячейки пустое (null), тогда функция вернет значение задаваемое параметром
			$(D_PARAM defaultValue). Этот параметр будет иметь значение null, если параметр опущен
		)
		+/
		string getStrByKey(string fieldName, PKValueType recordKey, string defaultValue) {
			return _recordSet.getStr(fieldName, getRecordIndex(recordKey), defaultValue);
		}

		/++
		$(LOCALE_EN_US
			Returns true if cell with field name $(D_PARAM fieldName) and record
			primary key $(D_PARAM recordKey) is null or false otherwise
		)
		$(LOCALE_RU_RU
			Возвращает true, если ячейка с именем поля $(D_PARAM fieldName) и
			первичным ключом записи $(D_PARAM recordKey) пуста (null). В противном
			случае возвращает false
		)
		+/
		bool isNullByKey(string fieldName, PKValueType recordKey) {
			return _recordSet.isNull(fieldName, getRecordIndex(recordKey));
		}
	
		/++
		$(LOCALE_EN_US Returns record index by it's primary $(D_PARAM key))
		$(LOCALE_RU_RU Возвращает порядковый номер записи по первичному ключу $(D_PARAM key))
		+/
		size_t getRecordIndex(PKValueType key)
		{
			import std.conv: to;
			return _recordSet.getIndexByStringKey(key.to!string);
		}

		/++
		$(LOCALE_EN_US Returns record primary key by it's $(D_PARAM index) in set)
		$(LOCALE_RU_RU Возвращает первичный ключ записи по порядковому номеру $(D_PARAM index) в наборе)
		+/
		/++
		PKValueType getRecordKey(size_t index) {
			return _primaryKeys[index];
		}
		+/
	
	} //static if( hasKeyField )
	else
	{
		size_t keyFieldIndex() @property {
			assert(false, `RecordSet has no key field!`);
		}
	}

	template get(string fieldName)
	{	
		alias ValueType = FormatType.getValueType!(fieldName);

		/++
		$(LOCALE_EN_US
			Meturns value of cell with field name $(D_PARAM fieldName) and $(D_PARAM recordIndex).
			Parameter $(D_PARAM defaultValue) determines return value when cell in null
		)
		$(LOCALE_RU_RU
			Возвращает значение ячейки с именем поля $(D_PARAM fieldName) и номером записи
			$(D_PARAM recordIndex). Параметр $(D_PARAM defaultValue) определяет возвращаемое
			значение, когда значение ячейки пустое (null)
		)
		+/
		ValueType get(size_t recordIndex) {
			return _getTypedField!fieldName.get(recordIndex);
		}

		/++
		$(LOCALE_EN_US
			Returns value of cell with field name $(D_PARAM fieldName) and $(D_PARAM recordIndex).
			Parameter $(D_PARAM defaultValue) determines return value when cell in null
		)
		$(LOCALE_RU_RU
			Возвращает значение ячейки с именем поля $(D_PARAM fieldName) и номером записи
			$(D_PARAM recordIndex). Параметр $(D_PARAM defaultValue) определяет возвращаемое
			значение, когда значение ячейки пустое (null)
		)
		+/
		ValueType get(size_t recordIndex, ValueType defaultValue) {
			return _getTypedField!fieldName.get(recordIndex, defaultValue);
		}
	}

	/++
	$(LOCALE_EN_US
		Returns format for enumerated field with name $(D_PARAM fieldName). If field
		doesn't have enumerated type this will result in compile-time error
	)
	$(LOCALE_RU_RU
		Возвращает формат для перечислимого поля с именем $(D_PARAM fieldName). Если это
		поле не является перечислимым, то это породит ошибку компиляции
	)
	+/
	template getEnumFormat(string fieldName)
	{
		alias ValueType = FormatType.getValueType!(fieldName);
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);

		static if( isEnumFormat!(FieldFormatType) )
		{
			auto getEnumFormat() {
				return _getTypedField!fieldName.enumFormat;
			}
		} else {
			static assert(0, "Getting enum data is only available for enum field types!!!");
		}
	}
	
	RecordType front() @property {
		return getRecord(0);
	}

	bool empty() @property {
		return !_recordSet || _recordSet.length == 0;
	}

	static if( hasKeyField )
	{
		static if( is( RecordSetType : IBaseWriteableRecordSet ) ) {
			void nullifyByKey(string fieldName, PKValueType recordKey) {
				_recordSet.nullify(fieldName, getRecordIndex(recordKey));
			}
		}

		template setByKey(string fieldName)
		{
			alias ValueType = FormatType.getValueType!(fieldName);

			void setByKey(ValueType value, PKValueType recordKey) {
				_getTypedField!(fieldName, true).set(value, getRecordIndex(recordKey));
			}
		}
	}

	template set(string fieldName)
	{
		alias ValueType = FormatType.getValueType!(fieldName);

		void set(ValueType value, size_t recordIndex) {
			_getTypedField!(fieldName, true).set(value, recordIndex);
		}
	}

	static struct Range
	{
		private ThisRecordSet _rs;
		private size_t _index = 0;

		this(ThisRecordSet rs) {
			_rs = rs;
		}

		bool empty() @property {
			return _index >= _rs.length;
		}
	
		RecordType front() @property
		{
			assert(_index < _rs.length);
			return _rs.getRecord(_index);
		}

		void popFront() {
			++_index;
		}
	}

	Range opSlice() {
		return Range(this);
	}

	public auto recordSet() @property {
		return _recordSet;
	}

	alias recordSet this;
}

unittest
{
	import webtank.datctrl.memory_data_field;
	import webtank.datctrl.record_set;

	auto recFormat = RecordFormat!(
		PrimaryKey!(size_t), "num",
		string, "name"
	)();
	IBaseWriteableDataField[] dataFields = makeMemoryDataFields(recFormat);
	auto baseRS = new WriteableRecordSet(dataFields);
	auto rs = TypedRecordSet!(typeof(recFormat), IBaseWriteableRecordSet)(baseRS);
	rs.addItems(1);
	rs.set!"name"("testValue", 0);
	assert(rs.get!"name"(0) == "testValue");
}