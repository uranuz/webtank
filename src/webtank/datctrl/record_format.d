module webtank.datctrl.record_format;

import webtank._version;

static if( isDatCtrlEnabled ) {

import std.typetuple, std.typecons, std.conv, std.json, std.traits;

import webtank.common.optional, webtank.datctrl.data_field, webtank.datctrl.enum_format, webtank.common.serialization, webtank.common.utils;

/++
$(LOCALE_EN_US Struct representing format of record or record set)
$(LOCALE_RU_RU Структура представляющая формат записи или набора записей)
+/
struct RecordFormat(Args...)
{	
	alias EnumFormatDecls = filterFieldFormatDecls!( EnumFormat );
	alias EnumFieldSpecs = _filterFieldSpecs!(_fieldSpecs).ByTypes!(EnumFormat);
	
	bool[string] nullableFlags; ///Флаги "обнулябельности"
	Tuple!(EnumFormatDecls) enumFormats;
	
	enum bool hasKeyField = Filter!(isPrimaryKeyFieldSpec, _fieldSpecs).length > 0;
	
	template setEnumFormat(string fieldName)
	{
		alias enumFormatIndex = _getFieldIndex!(fieldName, 0, EnumFieldSpecs);
		alias EnumFormatType = _getFieldSpec!(fieldName, EnumFieldSpecs).FormatDecl;
		
		void setEnumFormat(EnumFormatType enumFormat) inout
		{
			enumFormats[enumFormatIndex] = enumFormat;
		}
	}

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
	alias _fieldSpecs = _parseRecordFormatArgs!Args;
	
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
	///Шаблон возвращает кортеж имён полей отфильтрованных по типам FilterDecls
	///Элементы кортежа FilterDecls должны иметь тип FieldType
	template filterNamesByTypes(FilterDecls...)
	{	alias filterNamesByTypes = _getFieldNameTuple!( _filterFieldSpecs!(_fieldSpecs).ByTypes!(FilterDecls) );
	}
	
	template filterFieldFormatDecls(FilterDecls...)
	{
		alias filterFieldFormatDecls = _getFieldFormatDeclTuple!( _filterFieldSpecs!(_fieldSpecs).ByTypes!(FilterDecls) );
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
	template getFieldFormatDecl(string fieldName)
	{	alias getFieldFormatDecl = _getFieldSpec!(fieldName, _fieldSpecs).FormatDecl;
	}

	/++
	$(LOCALE_EN_US Template returns semantic field type $(D FieldType) for field with index $(D_PARAM fieldIndex))
	$(LOCALE_RU_RU Шаблон возвращает семантический тип поля $(D FieldType) для поля с номером $(D_PARAM fieldIndex))
	+/
	template getFieldFormatDecl(size_t fieldIndex)
	{	alias getFieldFormatDecl = _getFieldSpec!(fieldIndex, _fieldSpecs).FormatDecl;
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
	
	
	alias isPrimaryKeyFieldSpec(alias FieldSpec) = isPrimaryKeyFormat!(FieldSpec.FormatDecl);
	
	template getKeyFieldIndex()
	{
		alias PKFieldSpecs = Filter!(isPrimaryKeyFieldSpec, _fieldSpecs);
		static assert( PKFieldSpecs.length > 0, "Primary key is not set for record format!!!" );
		static assert( PKFieldSpecs.length < 1, "Only one primary key allowed for record format!!!" );
		
		alias getKeyFieldIndex = _getFieldIndex!(PKFieldSpecs[0].name, 0, _fieldSpecs);
	}
	
	
	template getKeyFieldSpec()
	{
		alias PKFieldSpecs = Filter!(isPrimaryKeyFieldSpec, _fieldSpecs);
		static assert( PKFieldSpecs.length > 0, "Primary key is not set for record format!!!" );
		static assert( PKFieldSpecs.length < 1, "Only one primary key allowed for record format!!!" );
		
		alias getKeyFieldIndex = PKFieldSpecs[0];
	}
}


template makeRecordFormat(Args...)
{
	import std.typetuple;
	
	template _MakeFieldSpec( T, string s, alias v )
	{	
		alias Spec = FieldSpec!( T, s );
		alias values = v;
	}

	template _parseMakeRecordFormatArgs(Args...)
	{	
		static if( Args.length == 0 )
		{	alias _parseMakeRecordFormatArgs = TypeTuple!() ;
		}
		else static if(  is( typeof(Args[0]) ) && isEnumFormat!( typeof(Args[0]) )  )
		{
			static if( is( typeof( Args[1] ) : string ) )
				alias _parseMakeRecordFormatArgs = 
					TypeTuple!( _MakeFieldSpec!(typeof(Args[0]), Args[1], Args[0]), _parseMakeRecordFormatArgs!(Args[2 .. $]) ) ;
			else
				alias _parseMakeRecordFormatArgs = 
					TypeTuple!( _MakeFieldSpec!(typeof(Args[0]), null, Args[0]), _parseMakeRecordFormatArgs!(Args[1 .. $]) ) ;
		}
		else static if( is(Args[0]) )
		{	
			static if( is( typeof( Args[1] ) : string ) )
				alias _parseMakeRecordFormatArgs = 
					TypeTuple!( _MakeFieldSpec!(Args[0], Args[1], Args[0].init), _parseMakeRecordFormatArgs!(Args[2 .. $]) ) ;
			else
				alias _parseMakeRecordFormatArgs = 
					TypeTuple!( _MakeFieldSpec!(Args[0], null, Args[0].init), _parseMakeRecordFormatArgs!(Args[1 .. $]) ) ;
		}
		else
		{	static assert(0, "Attempted to instantiate Tuple with an "
					~ "invalid argument: " ~ Args[0].stringof);
		}
	}
	
	enum bool _isEnumFormatMakeFieldSpec(alias MakeSpec) = isEnumFormat!( MakeSpec.Spec.FormatDecl );
	
	alias _makeFieldSpecs = _parseMakeRecordFormatArgs!(Args);
	//pragma(msg, "makeRecordFormat specs: ", _fieldSpecs);
	alias _enumFormatFieldSpecs = Filter!(_isEnumFormatMakeFieldSpec, _makeFieldSpecs);
	//pragma(msg, "makeRecordFormat specsLength: ", _enumFormatFieldSpecs);
	
	template getEnumFormatValues(MakeSpecs...)
	{
		static if( MakeSpecs.length == 0 )
			alias getEnumFormatValues = TypeTuple!();
		else static if( MakeSpecs.length == 1 )
			alias getEnumFormatValues = TypeTuple!( MakeSpecs[0].values );
		else
			alias getEnumFormatValues = TypeTuple!( MakeSpecs[0].values, getEnumFormatValues!(MakeSpecs[1..$]) );
	}

	template expandFieldSpecs(FieldSpecs...)
	{
		static if( FieldSpecs.length == 0 )
			alias expandFieldSpecs = TypeTuple!();
		else static if( FieldSpecs.length == 1 )
			alias expandFieldSpecs = 
				TypeTuple!( FieldSpecs[0].Spec.FormatDecl, FieldSpecs[0].Spec.name );
		else
			alias expandFieldSpecs = 
				TypeTuple!( FieldSpecs[0].Spec.FormatDecl, FieldSpecs[0].Spec.name, expandFieldSpecs!(FieldSpecs[1..$]) );	
	}
	
	
	alias RecordFormatArgs = expandFieldSpecs!(_makeFieldSpecs);
	
	auto makeRecordFormat()
	{	
		auto enumFormats = tuple( getEnumFormatValues!(_enumFormatFieldSpecs) );
		return RecordFormat!(RecordFormatArgs)(null, enumFormats);
	}
	
	auto makeRecordFormat(bool[string] nullableFlags)
	{	
		auto enumFormats = tuple( getEnumFormatValues!(_enumFormatFieldSpecs) );
		return RecordFormat!(RecordFormatArgs)(nullableFlags, enumFormats);
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

template _getFieldFormatDeclTuple(FieldSpecs...)
{
	static if( FieldSpecs.length == 0 )
		alias _getFieldFormatDeclTuple = TypeTuple!();
	else
		alias _getFieldFormatDeclTuple = TypeTuple!( FieldSpecs[0].FormatDecl, _getFieldFormatDeclTuple!(FieldSpecs[1..$]) );
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
	{	
		static if( __traits(isSame, FilterFieldTypes[0], EnumFormat) && 
			isInstanceOf!(EnumFormat, FieldSpec.FormatDecl) )
		{
			alias _filterFieldSpec = FieldSpec;
		}
		else static if( is(FilterFieldTypes[0]) && is( FieldSpec.FormatDecl == FilterFieldTypes[0] ) )
		{
			alias _filterFieldSpec = FieldSpec;
		}
		else
			alias _filterFieldSpec = _filterFieldSpec!(FieldSpec, FilterFieldTypes[1..$]);
	}
}


} //static if( isDatCtrlEnabled )