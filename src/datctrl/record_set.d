module webtank.datctrl.record_set;

import webtank._version;

static if( isDatCtrlEnabled ) {

import std.typetuple, std.typecons, std.conv, std.json;

import webtank.datctrl.data_field, webtank.datctrl.record, webtank.datctrl.record_format, webtank.common.serialization;

// interface IBaseRecordSet
// {	
// 	
// }

/++
$(LOCALE_EN_US Class implements work with record set)
$(LOCALE_RU_RU Класс реализует работу с набором записей)
+/
template RecordSet(alias RecordFormatT)
{
	class RecordSet: /+IBaseRecordSet,+/ IStdJSONSerializeable
	{	
		//Тип формата для набора записей
		alias RecordFormatT FormatType; 
		
		//Тип записи, возвращаемый из набора записей
		alias Record!FormatType RecordType;  
		
	protected:
		IBaseDataField[] _dataFields;
		size_t _keyFieldIndex;
		
		size_t _currRecIndex;
	public:

		/++
		$(LOCALE_EN_US Serializes data of record at position $(D_PARAM index) into std.json)
		$(LOCALE_RU_RU Сериализует данные записи под номером $(D_PARAM index) в std.json)
		+/
		JSONValue getStdJSONDataAt(size_t index)
		{	JSONValue[] recJSON;
			recJSON.length = FormatType.tupleOfNames!().length;
			
			foreach( j, name; FormatType.tupleOfNames!() )
			{	if( this.isNullAt(name, index) )
					recJSON[j] = null;
				else
					recJSON[j] = webtank.common.serialization.getStdJSON( this.getAt!(name)(index) );
			}
			return JSONValue(recJSON);
		}
		
		/++
		$(LOCALE_EN_US Serializes format of record set into std.json)
		$(LOCALE_RU_RU Сериализует формат набора записей в std.json)
		+/
		JSONValue getStdJSONFormat()
		{	JSONValue[string] jValues;
			
			//Выводим номер ключевого поля
			jValues["kfi"] = _keyFieldIndex;
			
			//Выводим тип данных
			jValues["t"] = "recordset";
			
			//Образуем JSON-массив форматов полей
			JSONValue[] jFieldFormats;
			jFieldFormats.length = _dataFields.length;
			
			foreach( i, field; _dataFields )
				jFieldFormats[i] = field.getStdJSONFormat();
				
			jValues["f"] = jFieldFormats;

			return JSONValue(jValues);
		}

		/++
		$(LOCALE_EN_US Serializes format and data of record set into std.json)
		$(LOCALE_RU_RU Сериализует формат и данные набора данных в std.json)
		+/
		JSONValue getStdJSON()
		{	auto jValues = this.getStdJSONFormat();
			
			JSONValue[] jData;
			jData.length = this.length;
			
			foreach( i; 0..this.length )
				jData[i] = this.getStdJSONDataAt(i);
				
			jValues["d"] = jData;

			return jValues;
		}
		
		this(IBaseDataField[] dataFields)
		{	//Устанавливаем размер массива полей
			_dataFields = dataFields; 
		}

		/++
		$(LOCALE_EN_US Index operator for getting record by $(D_PARAM recordIndex))
		$(LOCALE_RU_RU Оператор индексирования для получения записи по номеру $(D_PARAM recordIndex))
		+/
		RecordType opIndex(size_t recordIndex) 
		{	return getRecordAt(recordIndex); }

		/++
		$(LOCALE_EN_US Method returns record by $(D_PARAM recordIndex))
		$(LOCALE_RU_RU Метод возвращает запись на позиции $(D_PARAM recordIndex))
		+/
		RecordType getRecordAt(size_t recordIndex)
		{	return getRecord( getRecordKey(recordIndex) ); }

		/++
		$(LOCALE_EN_US Method returns record by it's primary $(D_PARAM recordKey))
		$(LOCALE_RU_RU Метод возвращает запись по первичному ключу $(D_PARAM recordKey))
		+/
		RecordType getRecord(size_t recordKey)
		{	return new RecordType(this, recordKey); }



		template get(string fieldName)
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
			ValueType get(size_t recordKey)
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
			ValueType get(size_t recordKey, ValueType defaultValue)
			{	return getAt!(fieldName)( getRecordIndex(recordKey), defaultValue ); }
		}

		template getAt(string fieldName)
		{	alias FormatType.getValueType!(fieldName) ValueType;
			alias FormatType.getFieldType!(fieldName) fieldType;
			alias FormatType.getFieldIndex!(fieldName) fieldIndex;

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
			ValueType getAt(size_t recordIndex)
			{	auto currField = cast(IDataField!(fieldType)) _dataFields[fieldIndex];
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
			ValueType getAt(size_t recordIndex, ValueType defaultValue)
			{	auto currField = cast(IDataField!(fieldType)) _dataFields[fieldIndex];
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
		{	alias FormatType.getValueType!(fieldName) ValueType;
			alias FormatType.getFieldType!(fieldName) fieldType;
			alias FormatType.getFieldIndex!(fieldName) fieldIndex;
			
			static if( fieldType == FieldType.Enum )
			{	auto getEnumFormat()
				{	auto currField = cast(IDataField!(fieldType)) _dataFields[fieldIndex];
					return currField.enumFormat();
				}
			}
			else
				static assert( 0, "Getting enum data is only available for enum field types!!!" );
		}

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
		string getStr(string fieldName, size_t recordKey, string defaultValue = null)
		{	return this.getStrAt( fieldName, getRecordIndex(recordKey), defaultValue ); }


		/++
		$(LOCALE_EN_US
			Method returns string representation of cell with field name $(D_PARAM fieldName)
			and record index $(D_PARAM recordIndex). If value of cell is empty then
			it return value specified by $(D_PARAM defaultValue) parameter, which will
			have null value if parameter is missed.
		)
		$(LOCALE_RU_RU
			Метод возвращает строковое представление ячейки с именем поля $(D_PARAM fieldName)
			и значением порядкового номера записи $(D_PARAM recordIndex). Если значение
			ячейки пустое (null), тогда функция вернет значение задаваемое параметром
			$(D_PARAM defaultValue). Этот параметр будет иметь значение null, если параметр опущен
		)
		+/
		string getStrAt(string fieldName, size_t recordIndex, string defaultValue = null)
		{	auto currField = _dataFields[ FormatType.indexes[fieldName] ];
			return currField.getStr( recordIndex, defaultValue );
		}


		/++
		$(LOCALE_EN_US Implements property for getting current record in range interface)
		$(LOCALE_RU_RU
			Реализует свойство для получения текущей записи в интерфейсе диапазона
			(аналог итераторов в C++)
		)
		+/
		RecordType front() @property
		{	return new RecordType( this, getRecordKey(_currRecIndex) );
		}

		/++
		$(LOCALE_EN_US Function shifts front edge of range forward)
		$(LOCALE_RU_RU Функция сдвигает фронт диапазона вперед)
		+/
		void popFront()
		{	_currRecIndex++; }

		/++
		$(LOCALE_EN_US Property returns true if range contains no elements)
		$(LOCALE_RU_RU Функция возвращает true, если диапазон не содержит элементов)
		+/
		bool empty() @property
		{	if( _currRecIndex < this.length  )
				return false;
			else
			{	_currRecIndex = 0;
				return true;
			}
		}
		
		/++
		$(LOCALE_EN_US Function returns index of field considered as primary key field)
		$(LOCALE_RU_RU Функция возвращает номер поля рассматриваемого как первичный ключ)
		+/
		size_t keyFieldIndex() @property
		{	return _keyFieldIndex;
		}

		/++
		$(LOCALE_EN_US Function sets primary key field by $(D_PARAAM index))
		$(LOCALE_RU_RU Функция задает поле первичного ключа по номеру $(D_PARAAM index))
		+/
		void setKeyField(size_t index)
		{	auto keyFieldIndexes = getKeyFieldIndexes!(FormatType._fieldSpecs)();
			foreach( i; keyFieldIndexes )
			{	if( i == index )
				{	_keyFieldIndex = index;
					return;
				}
			}
			assert( 0, "Field with index \"" ~ index.to!string ~ "\" isn't found or can't be used as primary key!" );
		}

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
		bool isNull(string fieldName, size_t recordKey)
		{	return this.isNullAt( fieldName, getRecordIndex(recordKey) ); }

		/++
		$(LOCALE_EN_US
			Function returns true if cell with field name $(D_PARAM fieldName) and record
			index $(D_PARAM recordIndex) is null or false otherwise
		)
		$(LOCALE_RU_RU
			Функция возвращает true, если ячейка с именем поля $(D_PARAM fieldName) и
			номером записи в наборе $(D_PARAM recordIndex) пуста (null). В противном
			случае возвращает false
		)
		+/
		bool isNullAt(string fieldName, size_t recordIndex)
		{	auto currField = _dataFields[ FormatType.indexes[fieldName] ];
			return currField.isNull( recordIndex );
		}

		/++
		$(LOCALE_EN_US
			Function returns true if cell with field name $(D_PARAM fieldName) can
			be null or false otherwise
		)
		$(LOCALE_RU_RU
			Функция возвращает true, если ячейка с именем поля $(D_PARAM fieldName)
			может быть пустой (null). В противном случае возвращает false
		)
		+/
		bool isNullable(string fieldName)
		{	auto currField = _dataFields[ FormatType.indexes[fieldName] ];
			return currField.isNullable();
		}

		/++
		$(LOCALE_EN_US Function returns number of record in set)
		$(LOCALE_RU_RU Функция возвращает количество записей в наборе)
		+/
		size_t length() @property
		{	assert( _dataFields[_keyFieldIndex].type == FieldType.IntKey, "Field with index " 
				~ _keyFieldIndex.to!string ~ " is not a key field!!!" ); 
			auto keyField = cast( IDataField!(FieldType.IntKey) ) _dataFields[_keyFieldIndex];
			return keyField.length;
		}

		/++
		$(LOCALE_EN_US Function returns record index by it's primary $(D_PARAM key))
		$(LOCALE_RU_RU Метод возвращает порядковый номер записи по первичному ключу $(D_PARAM key))
		+/
		size_t getRecordIndex(size_t key)
		{	assert( _dataFields[_keyFieldIndex].type == FieldType.IntKey, "Field with index " 
				~ _keyFieldIndex.to!string ~ " is not a key field!!!" ); 
			auto keyField = cast( IDataField!(FieldType.IntKey) ) _dataFields[_keyFieldIndex];
			return keyField.getIndex(key);
		}

		/++
		$(LOCALE_EN_US Function returns record primary key by it's $(D_PARAM index) in set)
		$(LOCALE_RU_RU
			Метод возвращает первичный ключ записи по порядковому номеру
			$(D_PARAM index) в наборе
		)
		+/
		size_t getRecordKey(size_t index)
		{	assert( _dataFields[_keyFieldIndex].type == FieldType.IntKey, "Field with index " 
				~ _keyFieldIndex.to!string ~ " is not a key field!!!" ); 
			auto keyField = cast( IDataField!(FieldType.IntKey) ) _dataFields[_keyFieldIndex];
			return keyField.getKey(index);
		}
		
	}
}


} //static if( isDatCtrlEnabled )
