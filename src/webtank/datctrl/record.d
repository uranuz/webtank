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
	
	string getStr(string fieldName);
	
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
	
	bool isWriteable(string fieldName);

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
		enum bool hasKeyField = RecordFormatT.hasKeyField;
		
		static if( hasKeyField )
		{
			//pragma(msg, RecordFormatT.getKeyFieldSpec!());
			alias PKValueType = RecordFormatT.getKeyFieldSpec!().ValueType;
		}
		
		private alias RecordSet!FormatType RecordSetType;
		
	protected:
		RecordSetType _recordSet;
		
		static if( hasKeyField )
			PKValueType _recordKey;
		else
			size_t _recordIndex;
	
	public:
		
		//Сериализаци записи в std.json
		JSONValue getStdJSON()
		{	
			JSONValue jValue = _recordSet.getStdJSONFormat();
			
			static if( hasKeyField )
				jValue.object["d"] = _recordSet.getStdJSONDataAt( _recordSet.getRecordIndex(_recordKey) );
			else
				jValue.object["d"] = _recordSet.getStdJSONDataAt( _recordIndex );
				
			jValue.object["t"] = "record";

			return jValue;
		}
		
		static if( hasKeyField )
		{
			this(RecordSetType recordSet, PKValueType recordKey)
			{	_recordSet = recordSet;
				_recordKey = recordKey;
			}
		}
		else
		{
			this(RecordSetType recordSet, size_t recordIndex)
			{	_recordSet = recordSet;
				_recordIndex = recordIndex;
			}
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
			{	
				static if( hasKeyField )
					return _recordSet.get!(fieldName)(_recordKey);
				else
					return _recordSet.getAt!(fieldName)(_recordIndex);
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
			{	
				static if( hasKeyField )
					return _recordSet.get!(fieldName)(_recordKey, defaultValue);
				else
					return _recordSet.getAt!(fieldName)(_recordIndex, defaultValue);
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
			string getStr(string fieldName)
			{	
				static if( hasKeyField )
					return _recordSet.getStr( fieldName, _recordKey);
				else
					return _recordSet.getStrAt( fieldName, _recordIndex);
			}
			
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
			string getStr(string fieldName, string defaultValue)
			{	
				static if( hasKeyField )
					return _recordSet.getStr( fieldName, _recordKey, defaultValue );
				else
					return _recordSet.getStrAt( fieldName, _recordIndex, defaultValue );
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
			{	
				static if( hasKeyField )
					return _recordSet.isNull(fieldName, _recordKey);
				else
					return _recordSet.isNullAt(fieldName, _recordIndex);
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
			
			bool isWriteable(string fieldName)
			{	return _recordSet.isWriteable(fieldName);
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


class IndependentRecord(alias RecordFormatT): IBaseRecord
{
	alias FormatType = RecordFormatT;
	alias ValueTypes = FormatType.getFieldValueTypes!();
	
	pragma(msg, "tupleOfNames: ", FormatType.tupleOfNames!()[0]);
protected:
	Tuple!(ValueTypes) _values;
	bool[] _nullFlags;
	bool[] _nullableFlags;
	bool[] _writeableFlags;
	
	size_t[string] _indexes;

public:
	this() {}

	void _readIndexes()
	{
		foreach( i, name; FormatType.names )
		{
			_indexes[name] = i;
		}
	}

	template get(string fieldName)
	{	
		alias FormatType.getValueType!(fieldName) ValueType;
		
		alias fieldIndex = FormatType.getFieldIndex!(fieldName);

		ValueType get()
		{	
			return _values[fieldIndex];
		}

		ValueType get(ValueType defaultValue)
		{	
			return _nullFlags[fieldIndex] ? defaultValue : _values[fieldIndex];
		}
	}
	
	template set(string fieldName)
	{
		alias FormatType.getValueType!(fieldName) ValueType;
		
		alias fieldIndex = FormatType.getFieldIndex!(fieldName);
		
		void set(ValueType value)
		{
			_values[fieldIndex] = value;
			_nullableFlags[fieldIndex] = false;
		
		}
	
	}
	
	override 
	{
		string getStr(string fieldName)
		{	
			if( isNull(fieldName) )
				return null;
			else
			{
				foreach( i, name ; FormatType.tupleOfNames!() )
				{
					if( name == fieldName )
						return _values[i].to!string;
				}
			}
			assert(0, `Field with name "` ~ fieldName ~ `" does not exist!!!`);
			
			return null;
		}
		

		string getStr(string fieldName, string defaultValue)
		{	
			if( isNull(fieldName) )
				return defaultValue;
			else
			{
				foreach( i, name ; FormatType.tupleOfNames!() )
				{
					if( name == fieldName )
						return _values[i].to!string;
				}
			}
			
			assert(0, `Field with name "` ~ fieldName ~ `" does not exist!!!`);
		}

		bool isNull(string fieldName)
		{	
			foreach( i, name ; FormatType.tupleOfNames!() )
			{
				if( name == fieldName )
					return _nullFlags[i];
			}

			assert(0, `Field with name "` ~ fieldName ~ `" does not exist!!!`);
		}

		bool isNullable(string fieldName)
		{	
			foreach( i, name ; FormatType.tupleOfNames!() )
			{
				if( name == fieldName )
					return _nullableFlags[i];
			}

			assert(0, `Field with name "` ~ fieldName ~ `" does not exist!!!`);
		}
		
		bool isWriteable(string fieldName)
		{	
			foreach( i, name ; FormatType.tupleOfNames!() )
			{
				if( name == fieldName )
					return _writeableFlags[i];
			}

			assert(0, `Field with name "` ~ fieldName ~ `" does not exist!!!`);
		}
		
		size_t length() @property
		{	return _values.length;
		}
	} // override

}

} //static if( isDatCtrlEnabled )
