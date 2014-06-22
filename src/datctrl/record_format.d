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
	$(LOCALE_EN_US Property returns array of semantic types of fields)
	$(LOCALE_RU_RU Свойство возвращает массив семантических типов полей)
	+/
	static pure FieldType[] types() @property
	{	FieldType[] result;
		foreach( spec; _fieldSpecs )
			result ~= spec.fieldType;
		return result;
	}

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
	{	alias _getFieldNameTuple!( _filterFieldSpecs!(_fieldSpecs).ByTypes!(FilterFieldTypes) ) filterNamesByTypes;
	}

	/++
	$(LOCALE_EN_US Template returns tuple of all field names for record format)
	$(LOCALE_RU_RU Шаблон возвращает кортеж всех имен полей для формата записи)
	+/
	template tupleOfNames()
	{	alias _getFieldNameTuple!(_fieldSpecs) tupleOfNames;
	}

	/++
	$(LOCALE_EN_US Template returns semantic field type $(D FieldType) for field with name $(D_PARAM fieldName))
	$(LOCALE_RU_RU Шаблон возвращает семантический тип поля $(D FieldType) для поля с именем $(D_PARAM fieldName))
	+/
	template getFieldType(string fieldName)
	{	alias _getFieldSpec!(fieldName, _fieldSpecs).fieldType getFieldType;
	}

	/++
	$(LOCALE_EN_US Template returns semantic field type $(D FieldType) for field with index $(D_PARAM fieldIndex))
	$(LOCALE_RU_RU Шаблон возвращает семантический тип поля $(D FieldType) для поля с номером $(D_PARAM fieldIndex))
	+/
	template getFieldType(size_t fieldIndex)
	{	alias _getFieldSpec!(fieldIndex, _fieldSpecs).fieldType getFieldType;
	}

	/++
	$(LOCALE_EN_US Template returns D value type for field with name $(D_PARAM fieldName))
	$(LOCALE_RU_RU Шаблон возвращает тип языка D для поля с именем $(D_PARAM fieldName))
	+/
	template getValueType(string fieldName)
	{	alias _getFieldSpec!(fieldName, _fieldSpecs).ValueType getValueType;
	}
	
	/++
	$(LOCALE_EN_US Template returns D value type for field with index $(D_PARAM fieldIndex))
	$(LOCALE_RU_RU Шаблон возвращает тип языка D для поля с номером $(D_PARAM fieldIndex))
	+/
	template getValueType(size_t fieldIndex)
	{	alias _getFieldSpec!(fieldIndex, _fieldSpecs).ValueType getValueType;
	}

	/++
	$(LOCALE_EN_US Template returns name for field with index $(D_PARAM fieldIndex))
	$(LOCALE_RU_RU Шаблон возвращает имя для поля с номером $(D_PARAM fieldIndex))
	+/
	template getFieldName(size_t fieldIndex)
	{	alias _getFieldSpec!(fieldIndex, _fieldSpecs).name getFieldName;
	}

	/++
	$(LOCALE_EN_US Template returns index for field with name $(D_PARAM fieldName))
	$(LOCALE_RU_RU Шаблон возвращает номер для поля с именем $(D_PARAM fieldName))
	+/
	template getFieldIndex(string fieldName)
	{	alias _getFieldIndex!(fieldName, 0, _fieldSpecs) getFieldIndex;
	}
}

/++
$(LOCALE_EN_US Struct represents format for enumerated type of field)
$(LOCALE_RU_RU Структура представляет формат для перечислимого типа поля)
+/
///Формат для перечислимого поля
struct EnumFormat
{	
protected:
	string[int] _names;
	int[] _keys;
	string _defaultName;

public:

	//Конструктор формата получает на входе карту соответсвия
	//ключей названиям элементов и параметр сортировки ключей
	//(возрастающий по-умолчанию)
	this(immutable(string[int]) names, bool isAscendingOrder = true) immutable
	{	_names = names;
		import std.algorithm, std.exception;
		int[] keys = names.keys;
		
		if( isAscendingOrder )
			sort!("a < b")(keys);
		else
			sort!("a > b")(keys);
			
		_keys = assumeUnique(keys);
	}
	
	this(immutable(string[int]) names, string nullName, bool isAscendingOrder = true) immutable
	{	this(names, isAscendingOrder);
		_defaultName = nullName;
	}
	
	this( const(EnumFormat) format )
	{	foreach( key, name; format._names )
			_names[key] = name;
		
		_keys = format._keys.dup;
		_defaultName = format._defaultName;
	}
	
	EnumFormat mutCopy() @property const
	{	return EnumFormat(this);
	}
	
	/++
	$(LOCALE_EN_US Serializes enumerated field format into std.json)
	$(LOCALE_RU_RU Сериализует формат перечислимого типа в std.json)
	+/
	JSONValue getStdJSON() const
	{	JSONValue[string] jArray; //Массив полей для формата перечислимого типа
		
		//Словарь перечислимых значений (числовой ключ --> строковое имя)
		JSONValue[string] jEnumNames;
		
		foreach( key, name; _names )
			jEnumNames[key.to!string] = name;
		jArray["enum_n"] = jEnumNames;
		
		
		//Массив, определяющий порядок перечислимых значений
		JSONValue[] jEnumKeys;
		jEnumKeys.length = _keys.length;

		foreach( i, key; _keys )
			jEnumKeys[i] = key;
		jArray["enum_k"] = jEnumKeys;
		
		return JSONValue(jArray);
	}

	///Конструктор формата получает на входе карту соответсвия
	///ключей названиям элементов и массив ключей, определяющий
	///их порядок следования
// 	this(string[int] names, int[] keys)
// 	{	_names = names.idup;
// 		_keys = keys.idup;
// 	}


	/++
	$(LOCALE_EN_US Index operator for getting name of enumerated value by key)
	$(LOCALE_RU_RU оператор индексации для получения имени перичислимого значения по ключу)
	+/
	///Оператор индексации по ключам для получения имени значения
	///Возвращает null, если значения нет в контейнере
	string opIndex(K)(K key) const
		if( is( K == int ) )
	{	return _names.get( key, _defaultName ); }
	
	///Шаблонный оператор индексации по ключам для получения имени значения
	///Возвращает null, если значения нет в контейнере
	///Принимает в качестве параметра "занулябельные" ключи, определённые
	///через std.typecons.Nullable или NullableRef. Однако базовый тип
	///значения должен быть int
	string opIndex(K)(K key) const
		if( isOptional!(K) && is( OptionalValueType!(K) == int )  )
	{	return ( key.isNull ? _defaultName : _names.get( key.value, _defaultName ) ); }
	
	///Метод получения имени для перечислимого типа по ключю
	///с указанием значения по-умолчанию (на случай если имя для ключа не определено)
	string get(K)(K key, string defaultValue) const
		if( is( K == int ) )
	{	return _names.get(key, defaultValue); }
	
	///Шаблонный метод получения имени перечислимого типа по ключу типа
	///std.typecons.Nullable или NullableRef. Однако тип значения
	///в "занулябельных" переменных должен быть int
	string get(K)(K key, string defaultValue) const
		if( isOptional!(K) && is( OptionalValueType!(K) == int )  )
	{	return ( key.isNull ? defaultValue : _names.get( key.value, defaultValue) ); }
	
	
	//TODO: Разобраться что применять string* или bool
	///Оператор in для проверки наличия ключа в наборе значений перечислимого типа
	inout(string)* opBinaryRight(string op)(int key) inout 
		if( op == "in" )
	{	return key in _names; }
	
	///Возвращает набор названий значений перечислимого типа
	string[] names() @property const
	{	string[] result;
		foreach( key; _keys )
			result ~= _names[key];
		return result;
	}
	
	///Возвращает набор ключей для значений перечислимого типа
	int[] keys() @property const
	{	return _keys.dup;
	}
	
	///Возвращает имя для пустого значения (null) для перечислимого типа
	string defaultName() @property const
	{	return _defaultName; }
	
	///Оператор для обхода значений перечислимого типа через foreach
	///Первый параметр - имя (строка), второй - ключ (число)
	int opApply(int delegate(string name, int i) dg) const
	{	foreach( key; _keys )
		{	auto result = dg(_names[key], key);
			if(result)
				return result;
		}
		return 0;
	}
	
	///Оператор для обхода значений перечислимого типа через foreach
	///в случае одного параметра (ключа)
	int opApply(int delegate(int i) dg)
	{	foreach( key; _keys )
		{	auto result = dg(key);
			if(result)
				return result;
		}
		return 0;
	}
}


///В шаблоне хранится соответсвие между именем и типом поля
template FieldSpec( FieldType ft, string s = null )
{	alias ft fieldType;
	alias DataFieldValueType!(ft) ValueType;
	alias s name;
}

//Шаблон разбирает аргументы и находит соответсвие имен и типов полей
//Результат: кортеж элементов FieldSpec
template _parseRecordFormatArgs(Args...)
{	static if( Args.length == 0 )
	{	alias TypeTuple!() _parseRecordFormatArgs;
	}
	else static if( is( typeof( Args[0] ) : FieldType ) )
	{	static if( is( typeof( Args[1] ) : string ) )
			alias TypeTuple!(FieldSpec!(Args[0 .. 2]), _parseRecordFormatArgs!(Args[2 .. $])) _parseRecordFormatArgs;
		else 
			alias TypeTuple!(FieldSpec!(Args[0]), _parseRecordFormatArgs!(Args[1 .. $])) _parseRecordFormatArgs;
	}
	else
	{	static assert(0, "Attempted to instantiate Tuple with an "
				~"invalid argument: "~ Args[0].stringof);
	}
}

template _getFieldNameTuple(FieldSpecs...)
{	static if( FieldSpecs.length == 0 )
		alias TypeTuple!() _getFieldNameTuple;
	else
		alias TypeTuple!( FieldSpecs[0].name, _getFieldNameTuple!(FieldSpecs[1..$]) ) _getFieldNameTuple;
}

//Получить из кортежа элементов типа FieldSpec нужный элемент по имени
template _getFieldSpec(string fieldName, FieldSpecs...)
{	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with name \"" ~ fieldName ~ "\" is not found in container!!!");
	else static if( FieldSpecs[0].name == fieldName )
		alias FieldSpecs[0] _getFieldSpec;
	else
		alias _getFieldSpec!(fieldName, FieldSpecs[1 .. $]) _getFieldSpec;
}

//Получить из кортежа элементов типа FieldSpec нужный элемент по имени
template _getFieldSpec(size_t index, FieldSpecs...)
{	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with given index is not found in container!!!");
	else static if( index == 0 )
		alias FieldSpecs[0] _getFieldSpec;
	else
		alias _getFieldSpec!( index - 1, FieldSpecs[1 .. $]) _getFieldSpec;
}

template _getFieldIndex(string fieldName, size_t index, FieldSpecs...)
{	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with name \"" ~ fieldName ~ "\" is not found in container!!!");
	else static if( FieldSpecs[0].name == fieldName )
		alias index _getFieldIndex;
	else 
		alias _getFieldIndex!(fieldName, index + 1 , FieldSpecs[1 .. $]) _getFieldIndex;
	
}

//Шаблон фильтрации кортежа элементов FieldSpec
template _filterFieldSpecs(FieldSpecs...)
{	//Фильтрация по типам полей
	//Элементы кортежа FilterFieldTypes должны иметь тип FieldType
	template ByTypes(FilterFieldTypes...)
	{	static if( FieldSpecs.length == 0 )
			alias TypeTuple!() ByTypes;
		else
			alias TypeTuple!(
				//Вызов фильтации для первого FieldSpec по набору FilterFieldTypes (типов полей)
				_filterFieldSpec!(FieldSpecs[0], FilterFieldTypes),
				
				//Вызов для остальных FieldSpecs
				_filterFieldSpecs!(FieldSpecs[1..$]).ByTypes!(FilterFieldTypes)
			) ByTypes;
	}
	
}

//Фильтрация одного элемента FieldSpec по набору типов полей
//Элементы кортежа FilterFieldTypes должны иметь тип FieldType
template _filterFieldSpec(alias FieldSpec, FilterFieldTypes...)
{	
	static if( FilterFieldTypes.length == 0 )
		alias TypeTuple!() _filterFieldSpec;
	else
	{	static if( FilterFieldTypes[0] == FieldSpec.fieldType )
			alias FieldSpec _filterFieldSpec;
		else
			alias _filterFieldSpec!(FieldSpec, FilterFieldTypes[1..$]) _filterFieldSpec;
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
