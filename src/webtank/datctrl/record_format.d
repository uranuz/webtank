module webtank.datctrl.record_format;

import webtank._version;

static if( isDatCtrlEnabled ) {

import std.meta: AliasSeq;
import std.typecons: Tuple;

import
	webtank.common.optional,
	webtank.datctrl.iface.data_field,
	webtank.datctrl.enum_format,
	webtank.common.std_json;

public import webtank.datctrl.iface.data_field: PrimaryKey, Writeable, FieldSpec;

/++
$(LANG_EN Struct representing format of record or record set)
$(LANG_RU Структура представляющая формат записи или набора записей)
+/
struct RecordFormat(Args...)
{
	// Результат разбора аргументов
	alias _argsParseRes = _parseRecordFormatArgs!(0, Args);

	//Внутреннее "хранилище" разобранной информации о полях записи
	//Не использовать извне!!!
	alias _fieldSpecs = _argsParseRes.FieldSpecs;

	alias EnumFieldSpecs = _filterFieldSpecs!(_fieldSpecs).ByTypes!(EnumFormat);
	alias EnumFormatTypes = _getFormatTypesTyple!(EnumFieldSpecs);

	// Идентификатор поля первичного ключа в формате записи
	enum size_t _keyFieldIndex = _argsParseRes.keyFieldIndex;

	bool[string] nullableFlags;
	Tuple!(EnumFormatTypes) enumFormats;

	/++
	$(LANG_EN Returns true if format includes primary key field)
	$(LANG_RU Возвращает true, если в формате есть поле первичного ключа)
	+/
	enum bool hasKeyField = _keyFieldIndex != size_t.max;

	/++
	$(LANG_EN Returns true if format includes at least one field with WriteableSpecAttr specification)
	$(LANG_RU Возвращает true, если в формате хотя бы одно поле со спецификацией WriteableSpecAttr)
	+/
	enum bool hasWriteableSpec = _hasWriteableSpec!_fieldSpecs;


	/++
	$(LANG_EN Returns instance of EnumFormat for specified field. Field should have enum type of course)
	$(LANG_RU Возвращает экземпляр структуры EnumFormat для поля с именем fieldName. Поле должно быть перечислимого типа)
	+/
	template getEnumFormat(string fieldName)
	{
		alias enumFormatIndex = _getFieldIndex!(fieldName, 0, EnumFieldSpecs);
		alias EnumFormatType = _getFieldSpec!(fieldName, EnumFieldSpecs).FormatType;

		EnumFormatType getEnumFormat() const {
			return enumFormats[enumFormatIndex];
		}
	}

	/++
	$(LANG_EN Set format of field with specified name that should have enum type)
	$(LANG_RU Устанвливает формат поля с именем fieldName, которое должно быть перечислимого типа)
	+/
	template setEnumFormat(string fieldName)
	{
		alias enumFormatIndex = _getFieldIndex!(fieldName, 0, EnumFieldSpecs);
		alias EnumFormatType = _getFieldSpec!(fieldName, EnumFieldSpecs).FormatType;

		void setEnumFormat(EnumFormatType enumFormat) inout {
			enumFormats[enumFormatIndex] = enumFormat;
		}
	}


	private static immutable(string[]) _names = ((){
		string[] result;
		static foreach( spec; _fieldSpecs )
			result ~= spec.name;
		return result;
	})();

	/++
	$(LANG_EN Returns array of field names for record format)
	$(LANG_RU Возвращает массив имен полей для формата записи)
	+/
	static pure immutable(string[]) names() @property {
		return _names;
	}

	private static immutable(size_t[string]) _indexes;

	shared static this()
	{
		static foreach( i, spec; _fieldSpecs )
			_indexes[spec.name] = i;
	}

	/++
	$(LANG_EN Returns AA of indexes of fields, indexed by their names)
	$(LANG_RU Возвращает словарь номеров полей данных, индексируемых их именами)
	+/
	static pure immutable(size_t[string]) indexes() @property {
		return _indexes;
	}

	//АХТУНГ!!! ДАЛЕЕ ИДУТ СТРАШНЫЕ ШАБЛОННЫЕ ЗАКЛИНАНИЯ!!!

	/++
	$(LANG_EN Returns tuple of all field names for record format)
	$(LANG_RU Возвращает кортеж всех имен полей для формата записи)
	+/
	alias tupleOfNames = _getFieldNameTuple!(_fieldSpecs);

	alias getFieldValueTypes = _getFieldValueTypes!(_fieldSpecs);

	/++
	$(LANG_EN Returns specification for field with name $(D_PARAM fieldName))
	$(LANG_RU Возвращает спецификацию для поля с именем $(D_PARAM fieldName))
	+/
	alias getFieldSpec(string fieldName) = _getFieldSpec!(fieldName, _fieldSpecs);

	/++
	$(LANG_EN Returns specification for field with index $(D_PARAM fieldIndex))
	$(LANG_RU Возвращает спецификацию для поля с индексом $(D_PARAM fieldIndex))
	+/
	alias getFieldSpec(size_t fieldIndex) = _getFieldSpec!(fieldIndex, _fieldSpecs);

	/++
	$(LANG_EN Returns semantic field type $(D FormatType) for field with name $(D_PARAM fieldName))
	$(LANG_RU Возвращает семантический тип поля $(D FormatType) для поля с именем $(D_PARAM fieldName))
	+/
	alias getFormatType(string fieldName) = getFieldSpec!(fieldName).FormatType;

	/++
	$(LANG_EN Returns semantic field type $(D FormatType) for field with index $(D_PARAM fieldIndex))
	$(LANG_RU Возвращает семантический тип поля $(D FormatType) для поля с номером $(D_PARAM fieldIndex))
	+/
	alias getFormatType(size_t fieldIndex) = getFieldSpec!(fieldIndex).FormatType;


	/++
	$(LANG_EN Returns D value type for field with name $(D_PARAM fieldName))
	$(LANG_RU Возвращает тип языка D для поля с именем $(D_PARAM fieldName))
	+/
	alias getValueType(string fieldName) = getFieldSpec!(fieldName).ValueType;

	/++
	$(LANG_EN Returns D value type for field with index $(D_PARAM fieldIndex))
	$(LANG_RU Возвращает тип языка D для поля с номером $(D_PARAM fieldIndex))
	+/
	alias getValueType(size_t fieldIndex) = getFieldSpec!(fieldIndex).ValueType;

	/++
	$(LANG_EN Returns name for field with index $(D_PARAM fieldIndex))
	$(LANG_RU Возвращает имя поля с номером $(D_PARAM fieldIndex))
	+/
	alias getFieldName(size_t fieldIndex) = getFieldSpec!(fieldIndex).name;

	/++
	$(LANG_EN Returns index for field with name $(D_PARAM fieldName))
	$(LANG_RU Возвращает номер для поля с именем $(D_PARAM fieldName))
	+/
	alias getFieldIndex(string fieldName) = _getFieldIndex!(fieldName, 0, _fieldSpecs);

	/++
	$(LANG_EN Returns index of primary key field if it is present)
	$(LANG_RU Возвращает номер поля первичного ключа, если оно присутствует)
	+/
	template getKeyFieldIndex()
	{
		static assert(_keyFieldIndex < _fieldSpecs.length, `No primary key field in record format`);

		enum getKeyFieldIndex = _keyFieldIndex;
	}

	/++
	$(LANG_EN Returns specification primary key field if it is present)
	$(LANG_RU Возвращает спецификацию поля первичного ключа, если оно присутствует)
	+/
	alias getKeyFieldSpec() = _fieldSpecs[getKeyFieldIndex!()];

	/++
		$(LANG_EN Returns index of field with specified name in record format)
		$(LANG_RU Возвращает номер поля с именем fieldName в формате записи)
	+/
	alias getEnumFormatIndex(string fieldName) = _getFieldIndex!(fieldName, 0, EnumFieldSpecs);

	/++
		$(LANG_EN Test if record format contains field with specified name)
		$(LANG_RU Проверяет наличие в формате поля с именем fieldName)
	+/
	enum bool hasField(string fieldName) = _getHasField!(fieldName, _fieldSpecs);
}


/// Проверяет наличие аттрибута записываемости хотя бы в одном поле формата записи
template _hasWriteableSpec(FieldSpecs...)
{
	static if( FieldSpecs.length == 0 ) {
		enum bool _hasWriteableSpec = false;
	} else static if( FieldSpecs[0].hasWriteableSpec ) {
		enum bool _hasWriteableSpec = true;
	} else {
		enum bool _hasWriteableSpec = _hasWriteableSpec!(FieldSpecs[1..$]);
	}
}


template _getHasField(string fieldName, FieldSpecs...)
{
	static if( FieldSpecs.length == 0 )
		enum bool _getHasField = false;
	else static if( FieldSpecs[0].name == fieldName  )
		enum bool _getHasField = true;
	else
		enum bool _getHasField = _getHasField!(fieldName, FieldSpecs[1..$]);
}


//Шаблон разбирает аргументы и находит соответсвие имен и типов полей
//Результат: кортеж элементов FieldSpecKind
template _parseRecordFormatArgs(size_t index, Args...)
{
	import std.traits: isInstanceOf;
	static if( Args.length == 0 )
	{
		alias FieldSpecs = AliasSeq!();
		enum size_t keyFieldIndex = size_t.max;
	}
	else
	{
		static if( Args.length > 1 && is(typeof( Args[1] ): string) )
		{
			enum string _fieldName = Args[1];
			alias _RestArgs = Args[2 .. $];
		}
		else
		{
			enum string _fieldName = null;
			alias _RestArgs = Args[1 .. $];
		}

		alias _Res = _parseRecordFormatArgs!(index + 1, _RestArgs);

		static if( isInstanceOf!(FieldSpec, Args[0]) )
		{
			alias _FieldSpec = Args[0];
		} else {
			alias _FieldSpec = FieldSpec!(Args[0], _fieldName);
		}

		static if( isInstanceOf!(FieldSpec, Args[0]) && Args[0].hasKeySpec ) {
			static assert(_Res.keyFieldIndex == size_t.max, `Multiple PrimaryKey field format specifiers detected!`);
			enum size_t keyFieldIndex = index;
		} else {
			enum size_t keyFieldIndex = _Res.keyFieldIndex;
		}

		alias FieldSpecs = AliasSeq!(_FieldSpec, _Res.FieldSpecs);
	}
}

template _getFieldValueTypes(FieldSpecs...)
{
	static if( FieldSpecs.length == 0 )
		alias _getFieldValueTypes = AliasSeq!();
	else
		alias _getFieldValueTypes = AliasSeq!( FieldSpecs[0].ValueType, _getFieldValueTypes!(FieldSpecs[1..$]) );
}

template _getFieldNameTuple(FieldSpecs...)
{
	static if( FieldSpecs.length == 0 )
		alias _getFieldNameTuple = AliasSeq!();
	else
		alias _getFieldNameTuple = AliasSeq!( FieldSpecs[0].name, _getFieldNameTuple!(FieldSpecs[1..$]) );
}

template _getFormatTypesTyple(FieldSpecs...)
{
	static if( FieldSpecs.length == 0 )
		alias _getFormatTypesTyple = AliasSeq!();
	else
		alias _getFormatTypesTyple = AliasSeq!( FieldSpecs[0].FormatType, _getFormatTypesTyple!(FieldSpecs[1..$]) );
}

//Получить из кортежа элементов типа FieldSpec нужный элемент по имени
template _getFieldSpec(string fieldName, FieldSpecs...)
{
	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with name \"" ~ fieldName ~ "\" is not found in container!!!");
	else static if( FieldSpecs[0].name == fieldName )
		alias _getFieldSpec = FieldSpecs[0];
	else
		alias _getFieldSpec = _getFieldSpec!(fieldName, FieldSpecs[1 .. $]);
}

//Получить из кортежа элементов типа FieldSpec нужный элемент по номеру
template _getFieldSpec(size_t index, FieldSpecs...)
{
	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with given index is not found in container!!!");
	else static if( index == 0 )
		alias _getFieldSpec = FieldSpecs[0];
	else
		alias _getFieldSpec = _getFieldSpec!( index - 1, FieldSpecs[1 .. $]);
}

template _getFieldIndex(string fieldName, size_t index, FieldSpecs...)
{
	static if( FieldSpecs.length == 0 )
		static assert(0, "Field with name \"" ~ fieldName ~ "\" is not found in container!!!");
	else static if( FieldSpecs[0].name == fieldName )
		alias _getFieldIndex = index;
	else
		alias _getFieldIndex = _getFieldIndex!(fieldName, index + 1 , FieldSpecs[1 .. $]);

}

//Шаблон фильтрации кортежа элементов FieldSpec
template _filterFieldSpecs(FieldSpecs...)
{	//Фильтрация по типам полей
	//Элементы кортежа FieldTypes должны иметь тип FieldType
	template ByTypes(FieldTypes...)
	{
		static assert( FieldTypes.length > 0, "Field types list must be provided!" );

		static if( FieldSpecs.length == 0 )
			alias ByTypes = AliasSeq!();
		else
			alias ByTypes = AliasSeq!(
				//Вызов фильтации для первого FieldSpec по набору FieldTypes (типов полей)
				_filterFieldSpec!(FieldSpecs[0], FieldTypes),

				//Вызов для остальных FieldSpecs
				_filterFieldSpecs!(FieldSpecs[1..$]).ByTypes!(FieldTypes)
			);
	}
}

//Фильтрация одного элемента FieldSpec по набору типов полей
//Элементы кортежа FieldTypes должны иметь тип FieldType
template _filterFieldSpec(alias FieldSpec, FieldTypes...)
{
	import std.traits: isInstanceOf;
	static if( FieldTypes.length == 0 ) {
		alias _filterFieldSpec = AliasSeq!();
	}
	else
	{
		static if(
			__traits(isSame, FieldTypes[0], EnumFormat) && isInstanceOf!(EnumFormat, FieldSpec.FormatType)
		) {
			alias _filterFieldSpec = FieldSpec;
		} else static if(
			is(FieldTypes[0]) && is( FieldSpec.FormatType == FieldTypes[0] )
		) {
			alias _filterFieldSpec = FieldSpec;
		} else {
			alias _filterFieldSpec = _filterFieldSpec!(FieldSpec, FieldTypes[1..$]);
		}
	}
}


} //static if( isDatCtrlEnabled )