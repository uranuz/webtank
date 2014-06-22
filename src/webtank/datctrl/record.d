module webtank.datctrl.record;

import webtank._version;

static if( isDatCtrlEnabled ) {

import std.typetuple, std.typecons, std.conv, std.json;

import   webtank.datctrl.data_field, webtank.datctrl.record_set, webtank.datctrl.record_format, webtank.db.database_field, webtank.common.serialization;

/++
$(LOCALE_EN_US Base interface for data record)
$(LOCALE_RU_RU Базовый интерфейс для записи данных)
+/
interface IBaseRecord
{
	/++
	$(LOCALE_EN_US Function returns string representation of value for field
		with name $(D_PARAM fieldName). Parameter $(D_PARAM defaultValue) determines
		returned value if value by $(D_PARAM index) is null
	)
	$(LOCALE_RU_RU Функция возвращает строковое представление значения для поля
		с именем $(D_PARAM fieldName). Параметр $(D_PARAM defaultValue) определяет
		возвращаемое значение, если возвращаемое значение пусто (null)
	)
	+/
	string getStr(string fieldName, string defaultValue);

	/++
	$(LOCALE_EN_US Function returns true if value for field with name $(D_PARAM fieldName)
		is null or returns false otherwise if it's not empty. 
	)
	$(LOCALE_RU_RU Функция возвращает true, если значения для поля с именем $(D_PARAM fieldName)
		является пустым (null) или false, если значение не пустое
	)
	+/
	bool isNull(string fieldName);

	/++
	$(LOCALE_EN_US Function returns true if value for field with name $(D_PARAM fieldName)
		could be null or returns false if it can't be null
	)
	$(LOCALE_RU_RU Функция возвращает true, если значения для поля с именем $(D_PARAM fieldName)
		может быть пустым (null) или false, если пустые значения не разрешены
	)
	+/
	bool isNullable(string fieldName);

	/++
	$(LOCALE_EN_US Returns number of fields in record)
	$(LOCALE_RU_RU Возвращает количество полей в записи)
	+/
	size_t length() @property;
}

template Record(alias RecordFormatT)
{	

	/++
	$(LOCALE_EN_US Class implements working with record)
	$(LOCALE_RU_RU Класс реализует работу с записью)
	+/
	class Record: IBaseRecord
	{
		//Тип формата для записи
		alias RecordFormatT FormatType;
		
		private alias RecordSet!FormatType RecordSetType;
		
	protected:
		RecordSetType _recordSet;
		size_t _recordKey;
	
	public:
		
		//Сериализаци записи в std.json
		JSONValue getStdJSON()
		{	
			JSONValue jValue = _recordSet.getStdJSONFormat();
			
			jValue["d"] = _recordSet.getStdJSONDataAt( _recordSet.getRecordIndex(_recordKey) );
			jValue["t"] = "record";

			return jValue;
		}
		
		this(RecordSetType recordSet, size_t recordKey)
		{	_recordSet = recordSet;
			_recordKey = recordKey;
		}


		template get(string fieldName)
		{	
			alias FormatType.getValueType!(fieldName) ValueType;

			/++
			$(LOCALE_EN_US Function for getting value for field with name $(D_PARAM fieldName).
				If field value is null then behaviour is undefined
			)
			$(LOCALE_RU_RU Функция получения значения для поля с именем $(D_PARAM fieldName).
				При пустом значении поля поведение не определено
			)
			+/
			ValueType get()
			{	return _recordSet.get!(fieldName)(_recordKey);
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
			ValueType get(ValueType defaultValue)
			{	return _recordSet.get!(fieldName)(_recordKey, defaultValue);
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
		auto getEnumFormat(string fieldName)()
		{	return _recordSet.getEnumFormat!(fieldName)();
		}
		
		override {
			/++
			$(LOCALE_EN_US Method returns string value representation for field with name $(D_PARAM fieldName).
				Parameter $(D_PARAM defaultValue) determines returned value if value
				for field with name $(D_PARAM fieldName) is null
			)
			$(LOCALE_RU_RU Метод возвращает формат для перечислимого поля с именем $(D_PARAM fieldName).
				Параметр $(D_PARAM defaultValue) определяет возвращаемое значение,
				если значение для поля с именем $(D_PARAM fieldName) является пустым (null)
			)
			+/
			string getStr(string fieldName, string defaultValue = null)
			{	return _recordSet.getStr( fieldName, _recordKey, defaultValue );
			}

			/++
			$(LOCALE_EN_US Method returns true if value for field with name $(D_PARAM fieldName)
				is null and false if it is not
			)
			$(LOCALE_RU_RU Метод возвращает true, если значение для поля с именем $(D_PARAM fieldName)
				является пустым или false в противном случае
			)
			+/
			bool isNull(string fieldName)
			{	return _recordSet.isNull(fieldName, _recordKey);
			}

			/++
			$(LOCALE_EN_US Function returns true if value for field with name $(D_PARAM fieldName)
				could be null or returns false if it can't be null
			)
			$(LOCALE_RU_RU Функция возвращает true, если значения для поля с именем $(D_PARAM fieldName)
				может быть пустым (null) или false, если пустые значения не разрешены
			)
			+/
			bool isNullable(string fieldName)
			{	return _recordSet.isNullable(fieldName);
			}
			
			/++
			$(LOCALE_EN_US Function returns number of fields in record)
			$(LOCALE_RU_RU Функция возвращает количество полей в записи)
			+/
			size_t length() @property
			{	return FormatType.tupleOfNames!().length;
			}
		
		} //override
		
		/++
		$(LOCALE_EN_US Property returns index of primary key field)
		$(LOCALE_RU_RU Свойство возвращает номер поля первичного ключа)
		+/
		size_t keyFieldIndex() @property
		{	return _recordSet.keyFieldIndex();
		}
	}
}


} //static if( isDatCtrlEnabled )
