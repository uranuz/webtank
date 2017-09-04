module webtank.datctrl.typed_record_set;

struct IRecordSet(alias RecordFormatT): IBaseRecordSet
{
	enum bool hasKeyField = RecordFormatT.hasKeyField;

	alias RecordType = IRecord!(RecordFormatT);

	static if( hasKeyField )
	{
		
		/++
		$(LOCALE_EN_US Method returns record by it's primary $(D_PARAM recordKey))
		$(LOCALE_RU_RU Метод возвращает запись по первичному ключу $(D_PARAM recordKey))
		+/
		RecordType getRecordByKey(PKValueType recordKey)
		{	return new RecordType(this, recordKey); }
		
		template getByKey(string fieldName)
		{	alias FormatType.getValueType!(fieldName) ValueType;

			/++
			$(LOCALE_EN_US
				Method returns value of cell with field name $(D_PARAM fieldName) and primary key
				value $(D_PARAM recordKey). If cell value is null then behaviour is undefined
			)
			$(LOCALE_RU_RU
				Метод возвращает значение ячейки с именем поля $(D_PARAM fieldName) и значением
				первичного ключа $(D_PARAM recordKey). Если значение ячейки пустое (null), то
				поведение не определено
			)
			+/
			ValueType getByKey(PKValueType recordKey)
			{	return get!(fieldName)( getRecordIndex(recordKey) ); }

			/++
			$(LOCALE_EN_US
				Method returns value of cell with field name $(D_PARAM fieldName) and primary key
				value $(D_PARAM recordKey). Parameter $(D_PARAM defaultValue) determines return
				value when cell in null
			)
			$(LOCALE_RU_RU
				Метод возвращает значение ячейки с именем поля $(D_PARAM fieldName) и значением
				первичного ключа $(D_PARAM recordKey). Параметр $(D_PARAM defaultValue)
				определяет возвращаемое значение, когда значение ячейки пустое (null)
			)
			+/
			ValueType getByKey(PKValueType recordKey, ValueType defaultValue)
			{	return get!(fieldName)( getRecordIndex(recordKey), defaultValue ); }
		}
	
		string getStrByKey(string fieldName, PKValueType recordKey)
		{	return this.getStr( fieldName, getRecordIndex(recordKey) ); }
		
		/++
		$(LOCALE_EN_US
			Method returns string representation of cell with field name $(D_PARAM fieldName)
			and record primary key $(D_PARAM recordKey). If value of cell is empty then
			it return value specified by $(D_PARAM defaultValue) parameter, which will
			have null value if parameter is missed.
		)
		$(LOCALE_RU_RU
			Метод возвращает строковое представление ячейки с именем поля $(D_PARAM fieldName)
			и значением первичного ключа записи $(D_PARAM recordKey). Если значение
			ячейки пустое (null), тогда функция вернет значение задаваемое параметром
			$(D_PARAM defaultValue). Этот параметр будет иметь значение null, если параметр опущен
		)
		+/
		string getStrByKey(string fieldName, PKValueType recordKey, string defaultValue)
		{	return this.getStr( fieldName, getRecordIndex(recordKey), defaultValue ); }



		/++
		$(LOCALE_EN_US
			Function returns true if cell with field name $(D_PARAM fieldName) and record
			primary key $(D_PARAM recordKey) is null or false otherwise
		)
		$(LOCALE_RU_RU
			Функция возвращает true, если ячейка с именем поля $(D_PARAM fieldName) и
			первичным ключом записи $(D_PARAM recordKey) пуста (null). В противном
			случае возвращает false
		)
		+/
		bool isNullByKey(string fieldName, PKValueType recordKey)
		{	return this.isNull( fieldName, getRecordIndex(recordKey) ); }
	
		/++
		$(LOCALE_EN_US Function returns record index by it's primary $(D_PARAM key))
		$(LOCALE_RU_RU Метод возвращает порядковый номер записи по первичному ключу $(D_PARAM key))
		+/
		size_t getRecordIndex(PKValueType key)
		{	return _recordIndexes[key];
		}

		/++
		$(LOCALE_EN_US Function returns record primary key by it's $(D_PARAM index) in set)
		$(LOCALE_RU_RU
			Метод возвращает первичный ключ записи по порядковому номеру
			$(D_PARAM index) в наборе
		)
		+/
		PKValueType getRecordKey(size_t index)
		{	return _primaryKeys[index];
		}
	
	} //static if( hasKeyField )
	else
	{
		size_t keyFieldIndex() @property
		{
			assert( false, `RecordSet has no key field!` );
		}
	}
	
	

	template get(string fieldName)
	{	
		alias ValueType = FormatType.getValueType!(fieldName);
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
		alias fieldIndex = FormatType.getFieldIndex!(fieldName);

		/++
		$(LOCALE_EN_US
			Method returns value of cell with field name $(D_PARAM fieldName) and $(D_PARAM recordIndex).
			Parameter $(D_PARAM defaultValue) determines return value when cell in null
		)
		$(LOCALE_RU_RU
			Метод возвращает значение ячейки с именем поля $(D_PARAM fieldName) и номером записи
			$(D_PARAM recordIndex). Параметр $(D_PARAM defaultValue) определяет возвращаемое
			значение, когда значение ячейки пустое (null)
		)
		+/
		ValueType get(size_t recordIndex)
		{	auto currField = cast(IDataField!(FieldFormatType)) _dataFields[fieldIndex];
			return currField.get( recordIndex );
		}

		/++
		$(LOCALE_EN_US
			Method returns value of cell with field name $(D_PARAM fieldName) and $(D_PARAM recordIndex).
			Parameter $(D_PARAM defaultValue) determines return value when cell in null
		)
		$(LOCALE_RU_RU
			Метод возвращает значение ячейки с именем поля $(D_PARAM fieldName) и номером записи
			$(D_PARAM recordIndex). Параметр $(D_PARAM defaultValue) определяет возвращаемое
			значение, когда значение ячейки пустое (null)
		)
		+/
		ValueType get(size_t recordIndex, ValueType defaultValue)
		{	auto currField = cast(IDataField!(FieldFormatType)) _dataFields[fieldIndex];
			return currField.get( recordIndex, defaultValue );
		}
	}

	/++
	$(LOCALE_EN_US
		Method returns format for enumerated field with name $(D_PARAM fieldName). If field
		doesn't have enumerated type this will result in compile-time error
	)
	$(LOCALE_RU_RU
		Метод возвращает формат для перечислимого поля с именем $(D_PARAM fieldName). Если это
		поле не является перечислимым, то это породит ошибку компиляции
	)
	+/
	template getEnumFormat(string fieldName)
	{
		alias ValueType = FormatType.getValueType!(fieldName);
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
		alias fieldIndex = FormatType.getFieldIndex!(fieldName);
		
		static if( isEnumFormat!(FormatType) )
		{	auto getEnumFormat()
			{	auto currField = cast(IDataField!(FieldFormatType)) _dataFields[fieldIndex];
				return currField.enumFormat;
			}
		}
		else
			static assert( 0, "Getting enum data is only available for enum field types!!!" );
	}

	static if( hasKeyField )
	{
		alias PKValueType = RecordFormatT.getKeyFieldSpec!().ValueType;
		
		RecordType getRecordByKey(PKValueType recordKey);
		
		string getStrByKey(string fieldName, PKValueType recordKey);
		string getStrByKey(string fieldName, PKValueType recordKey, string defaultValue);
		
		bool isNullByKey(string fieldName, PKValueType recordKey);
		
		size_t getRecordIndex(PKValueType key);
		PKValueType getRecordKey(size_t index);
		
		template getByKey(string fieldName)
		{	
			alias FormatType.getValueType!(fieldName) ValueType;

			/++
			$(LOCALE_EN_US
				Method returns value of cell with field name $(D_PARAM fieldName) and primary key
				value $(D_PARAM recordKey). If cell value is null then behaviour is undefined
			)
			$(LOCALE_RU_RU
				Метод возвращает значение ячейки с именем поля $(D_PARAM fieldName) и значением
				первичного ключа $(D_PARAM recordKey). Если значение ячейки пустое (null), то
				поведение не определено
			)
			+/
			final ValueType getByKey(PKValueType recordKey)
			{	return getAt!(fieldName)( getRecordIndex(recordKey) ); }

			/++
			$(LOCALE_EN_US
				Method returns value of cell with field name $(D_PARAM fieldName) and primary key
				value $(D_PARAM recordKey). Parameter $(D_PARAM defaultValue) determines return
				value when cell in null
			)
			$(LOCALE_RU_RU
				Метод возвращает значение ячейки с именем поля $(D_PARAM fieldName) и значением
				первичного ключа $(D_PARAM recordKey). Параметр $(D_PARAM defaultValue)
				определяет возвращаемое значение, когда значение ячейки пустое (null)
			)
			+/
			final ValueType getByKey(PKValueType recordKey, ValueType defaultValue)
			{	return getAt!(fieldName)( getRecordIndex(recordKey), defaultValue ); }
		}
	}
	
	RecordType front() @property;
	void popFront();
	bool empty() @property;
	
	template get(string fieldName)
	{	
		alias ValueType = FormatType.getValueType!(fieldName);
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
		alias fieldIndex = FormatType.getFieldIndex!(fieldName);

		/++
		$(LOCALE_EN_US
			Method returns value of cell with field name $(D_PARAM fieldName) and $(D_PARAM recordIndex).
			Parameter $(D_PARAM defaultValue) determines return value when cell in null
		)
		$(LOCALE_RU_RU
			Метод возвращает значение ячейки с именем поля $(D_PARAM fieldName) и номером записи
			$(D_PARAM recordIndex). Параметр $(D_PARAM defaultValue) определяет возвращаемое
			значение, когда значение ячейки пустое (null)
		)
		+/
		final ValueType get(size_t recordIndex)
		{	auto currField = cast(IDataField!(FieldFormatType)) this.getField(fieldIndex);
			return currField.get( recordIndex );
		}

		/++
		$(LOCALE_EN_US
			Method returns value of cell with field name $(D_PARAM fieldName) and $(D_PARAM recordIndex).
			Parameter $(D_PARAM defaultValue) determines return value when cell in null
		)
		$(LOCALE_RU_RU
			Метод возвращает значение ячейки с именем поля $(D_PARAM fieldName) и номером записи
			$(D_PARAM recordIndex). Параметр $(D_PARAM defaultValue) определяет возвращаемое
			значение, когда значение ячейки пустое (null)
		)
		+/
		final ValueType get(size_t recordIndex, ValueType defaultValue)
		{	auto currField = cast(IDataField!(FieldFormatType)) this.getField(fieldIndex);
			return currField.get( recordIndex, defaultValue );
		}
	}

}

struct IWriteableRecordSet(alias RecordFormatT): IRecordSet!(RecordFormatT), IBaseWriteableRecordSet
{
	enum bool hasKeyField = RecordFormatT.hasKeyField;
	alias RecordType = Record!(RecordFormatT);
	
	
	static if( hasKeyField )
	{
		alias PKValueType = RecordFormatT.getKeyFieldSpec!().ValueType;
		
		void nullify(string fieldName, PKValueType recordKey);
		void setNullable(string fieldName, PKValueType recordKey, bool value);
		
		
		template setByKey(string fieldName)
		{
			alias ValueType = FormatType.getValueType!(fieldName);
			alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
			alias fieldIndex = FormatType.getFieldIndex!(fieldName);
			
			final void setByKey(PKValueType recordKey, ValueType value)
			{
				auto dataField = cast( IWriteableDataField!(FieldFormatType) ) this.getField(fieldName);
				
				dataField.set( getRecordIndex(recordKey), value );
			}
		
		}
	}

	template set(string fieldName)
	{
		alias ValueType = FormatType.getValueType!(fieldName);
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
		alias fieldIndex = FormatType.getFieldIndex!(fieldName);
		
		final void set(size_t recordIndex, ValueType value)
		{
			auto dataField = cast( IWriteableDataField!(FieldFormatType) ) this.getField(fieldName);
				
			dataField.set( recordIndex, value );
		}
	
	}
}

class WriteableRecordSet(alias RecordFormatT): RecordSet!(RecordFormatT), IWriteableRecordSet!(RecordFormatT)
{
public:

	//Тип формата для набора записей
	alias RecordFormatT FormatType; 
	
	//Тип записи, возвращаемый из набора записей
	alias Record!FormatType RecordType;
	
	enum bool hasKeyField = RecordFormatT.hasKeyField;
	
	override {
		void nullify(string fieldName, size_t recordIndex)
		{
			_dataFields[ FormatType.indexes[fieldName] ].isNull( recordIndex );
		}
		
		
		void setNullable(string fieldName, bool value)
		{
		
		}
	}
	
	
	
	template setByKey(string fieldName)
	{
		alias ValueType = FormatType.getValueType!(fieldName);
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
		alias fieldIndex = FormatType.getFieldIndex!(fieldName);
		
		void setByKey(PKValueType recordKey, ValueType value)
		{
			auto dataField = cast(IWriteableDataField!(FieldFormatType)) _dataFields[fieldIndex];
			
			dataField.set( getRecordKey(recordIndex), value);
		}
	
	}
	
	template set(string fieldName)
	{
		alias ValueType = FormatType.getValueType!(fieldName);
		alias FieldFormatType = FormatType.getFieldFormatDecl!(fieldName);
		alias fieldIndex = FormatType.getFieldIndex!(fieldName);
	
		void set(size_t recordIndex, ValueType value)
		{
			auto dataField = cast(IWriteableDataField!(FieldFormatType)) _dataFields[fieldIndex];
			
			dataField.set(recordIndex, value);
		
		}
	
	}
}