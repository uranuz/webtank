module webtank.datctrl.record_format;

import webtank._version;

static if( isDatCtrlEnabled ) {

import std.typetuple, std.typecons, std.conv, std.json;

import webtank.common.optional, webtank.datctrl.data_field, webtank.db.database_field, webtank.common.serialization, webtank.common.utils;

/++
$(LOCALE_EN_US Struct representing format of record or record set)
$(LOCALE_RU_RU Структура представляющая формат записи или набора записей)
+/
struct RecordFormat(Args...)
{	
	size_t keyFieldIndex = 0; //Номер основного ключевого поля (если их несколько)
	//Флаги для полей, показывающие может ли значение поля быть пустым (null)
	//(если значение = true) или нет (false)
	bool[string] nullableFlags; ///Флаги "обнулябельности"
	EnumFormat[string] enumFormats; ///Возможные значения для перечислимых полей

	/++
	/++
	$(LOCALE_EN_US Property returns array of semantic types of fields)
	$(LOCALE_RU_RU Свойство возвращает массив семантических типов полей)
	+/
	static pure FieldType[] types() @property
	{	FieldType[] result;
		foreach( spec; _fieldSpecs )
			result ~= spec.fieldType;
		return result;
	}
	+/

	/++
	$(LOCALE_EN_US Property returns array of field names for record format)
	$(LOCALE_RU_RU Свойство возвращает массив имен полей для формата записи)
	+/
	static pure string[] names() @property
	{	string[] result;
		foreach( spec; _fieldSpecs )
			result ~= spec.name;
		return result;
	}

	/++
	$(LOCALE_EN_US Property returns AA of indexes of fields, indexed by their names)
	$(LOCALE_RU_RU Свойство возвращает словарь номеров полей данных, индексируемых их именами)
	+/
	static pure size_t[string] indexes() @property
	{	size_t[string] result;
		foreach( i, spec; _fieldSpecs )
			result[spec.name] = i;
		return result;
	}
	
	//Внутреннее "хранилище" разобранной информации о полях записи
	//Не использовать извне!!!
	alias _parseRecordFormatArgs!Args _fieldSpecs;
	
	//АХТУНГ!!! ДАЛЕЕ ИДУТ СТРАШНЫЕ ШАБЛОННЫЕ ЗАКЛИНАНИЯ!!!


	/++
	$(LOCALE_EN_US
		Template returns tuple of names for fields having semantic types from
		$(D_PARAM FilterFieldTypes) parameter. All elements from $(D_PARAM FilterFieldTypes)
		tuple must be of FieldType type
	)
	$(LOCALE_RU_RU
		Шаблон возвращает кортеж имен для полей, имеющих семантический тип из
		кортежа $(D_PARAM FilterFieldTypes). Все элементы в кортеже $(D_PARAM FilterFieldTypes)
		должны иметь тип FieldType
	)
	+/
	///Шаблон возвращает кортеж имён полей отфильтрованных по типам FilterFieldTypes
	///Элементы кортежа FilterFieldTypes должны иметь тип FieldType
	template filterNamesByTypes(FilterFieldTypes...)
	{	alias filterNamesByTypes = _getFieldNameTuple!( _filterFieldSpecs!(_fieldSpecs).ByTypes!(FilterFieldTypes) );
	}

	/++
	$(LOCALE_EN_US Template returns tuple of all field names for record format)
	$(LOCALE_RU_RU Шаблон возвращает кортеж всех имен полей для формата записи)
	+/
	template tupleOfNames()
	{	alias tupleOfNames = _getFieldNameTuple!(_fieldSpecs);
	}

	/++
	$(LOCALE_EN_US Template returns semantic field type $(D FieldType) for field with name $(D_PARAM fieldName))
	$(LOCALE_RU_RU Шаблон возвращает семантический тип поля $(D FieldType) для поля с именем $(D_PARAM fieldName))
	+/
	template getFormatType(string fieldName)
	{	alias getFormatType = _getFieldSpec!(fieldName, _fieldSpecs).Type;
	}

	/++
	$(LOCALE_EN_US Template returns semantic field type $(D FieldType) for field with index $(D_PARAM fieldIndex))
	$(LOCALE_RU_RU Шаблон возвращает семантический тип поля $(D FieldType) для поля с номером $(D_PARAM fieldIndex))
	+/
	template getFormatType(size_t fieldIndex)
	{	alias getFormatType = _getFieldSpec!(fieldIndex, _fieldSpecs).Type;
	}

	/++
	$(LOCALE_EN_US Template returns D value type for field with name $(D_PARAM fieldName))
	$(LOCALE_RU_RU Шаблон возвращает тип языка D для поля с именем $(D_PARAM fieldName))
	+/
	template getValueType(string fieldName)
	{	alias getValueType = _getFieldSpec!(fieldName, _fieldSpecs).ValueType;
	}
	
	/++
	$(LOCALE_EN_US Template returns D value type for field with index $(D_PARAM fieldIndex))
	$(LOCALE_RU_RU Шаблон возвращает тип языка D для поля с номером $(D_PARAM fieldIndex))
	+/
	template getValueType(size_t fieldIndex)
	{	alias getValueType = _getFieldSpec!(fieldIndex, _fieldSpecs).ValueType;
	}

	/++
	$(LOCALE_EN_US Template returns name for field with index $(D_PARAM fieldIndex))
	$(LOCALE_RU_RU Шаблон возвращает имя для поля с номером $(D_PARAM fieldIndex))
	+/
	template getFieldName(size_t fieldIndex)
	{	alias getFieldName = _getFieldSpec!(fieldIndex, _fieldSpecs).name;
	}

	/++
	$(LOCALE_EN_US Template returns index for field with name $(D_PARAM fieldName))
	$(LOCALE_RU_RU Шаблон возвращает номер для поля с именем $(D_PARAM fieldName))
	+/
	template getFieldIndex(string fieldName)
	{	alias getFieldIndex = _getFieldIndex!(fieldName, 0, _fieldSpecs);
	}
}


//Шаблон разбирает аргументы и находит соответсвие имен и типов полей
//Результат: кортеж элементов FieldSpec
template _parseRecordFormatArgs(Args...)
{	static if( Args.length == 0 )
	{	alias _parseRecordFormatArgs = TypeTuple!() ;
	}
	else static if( is(Args[0]) )
	{	
		static if( is( typeof( Args[1] ) : string ) )
			alias _parseRecordFormatArgs = TypeTuple!(FieldSpec!(Args[0 .. 2]), _parseRecordFormatArgs!(Args[2 .. $]));
		else 
			alias _parseRecordFormatArgs = TypeTuple!(FieldSpec!(Args[0]), _parseRecordFormatArgs!(Args[1 .. $]));
	}
	else
	{	static assert(0, "Attempted to instantiate Tuple with an "
				~ "invalid argument: " ~ Args[0].stringof);
	}
}

template _getFieldNameTuple(FieldSpecs...)
{	static if( FieldSpecs.length == 0 )
		alias _getFieldNameTuple = TypeTuple!();
	else
		alias _getFieldNameTuple = TypeTuple!( FieldSpecs[0].name, _getFieldNameTuple!(FieldSpecs[1..$]) );
}

//Получить из кортежа элементов типа FieldSpec нужный элемент по имени
template _getFieldSpec(string fieldName, FieldSpecs...)
{	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with name \"" ~ fieldName ~ "\" is not found in container!!!");
	else static if( FieldSpecs[0].name == fieldName )
		alias _getFieldSpec = FieldSpecs[0];
	else
		alias _getFieldSpec = _getFieldSpec!(fieldName, FieldSpecs[1 .. $]);
}

//Получить из кортежа элементов типа FieldSpec нужный элемент по номеру
template _getFieldSpec(size_t index, FieldSpecs...)
{	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with given index is not found in container!!!");
	else static if( index == 0 )
		alias _getFieldSpec = FieldSpecs[0];
	else
		alias _getFieldSpec = _getFieldSpec!( index - 1, FieldSpecs[1 .. $]);
}

template _getFieldIndex(string fieldName, size_t index, FieldSpecs...)
{	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with name \"" ~ fieldName ~ "\" is not found in container!!!");
	else static if( FieldSpecs[0].name == fieldName )
		alias _getFieldIndex = index;
	else 
		alias _getFieldIndex = _getFieldIndex!(fieldName, index + 1 , FieldSpecs[1 .. $]);
	
}

//Шаблон фильтрации кортежа элементов FieldSpec
template _filterFieldSpecs(FieldSpecs...)
{	//Фильтрация по типам полей
	//Элементы кортежа FilterFieldTypes должны иметь тип FieldType
	template ByTypes(FilterFieldTypes...)
	{	static if( FieldSpecs.length == 0 )
			alias ByTypes = TypeTuple!();
		else
			alias ByTypes = TypeTuple!(
				//Вызов фильтации для первого FieldSpec по набору FilterFieldTypes (типов полей)
				_filterFieldSpec!(FieldSpecs[0], FilterFieldTypes),
				
				//Вызов для остальных FieldSpecs
				_filterFieldSpecs!(FieldSpecs[1..$]).ByTypes!(FilterFieldTypes)
			);
	}
	
}

//Фильтрация одного элемента FieldSpec по набору типов полей
//Элементы кортежа FilterFieldTypes должны иметь тип FieldType
template _filterFieldSpec(alias FieldSpec, FilterFieldTypes...)
{	
	static if( FilterFieldTypes.length == 0 )
		alias _filterFieldSpec = TypeTuple!();
	else
	{	static if( is( FilterFieldTypes[0] == FieldSpec.Type ) )
			alias _filterFieldSpec = FieldSpec;
		else
			alias _filterFieldSpec = _filterFieldSpec!(FieldSpec, FilterFieldTypes[1..$]);
	}
}

//Получение списка индексов всех ключевых полей
size_t[] getKeyFieldIndexes(FieldSpecs...)()
{	size_t[] result;
	foreach( i, spec; FieldSpecs )
		if( spec.fieldType == FieldType.IntKey )
			result ~= i;
	return result;
}


} //static if( isDatCtrlEnabled )
