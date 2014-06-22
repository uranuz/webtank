module webtank.datctrl.data_field;

import webtank._version;

static if( isDatCtrlEnabled ) {

import std.array, std.conv, std.json, std.datetime;

import   webtank.datctrl.record_format;

/++
$(LOCALE_EN_US
	Enumerable representing types of possible data fields
)

$(LOCALE_RU_RU
	Перечислимый тип представляющий типы возможных полей данных
)
+/
enum FieldType { Str, Int, Bool, IntKey, Date, Enum, Text };

/++
$(LOCALE_EN_US
	String values representing values that treated as boolean true value
)

$(LOCALE_RU_RU
	Строковые значения, которые трактуются как true при преобразовании типов
)
+/

immutable(string[]) _logicTrueValues = 
		 [`true`, `t`, `yes`, `y`, `on`, `истина`, `и`, `да`, `д`];
		 
immutable(string[]) _logicFalseValues = 
		 [`false`, `f`, `no`, `n`, `off`, `ложь`, `л`, `нет`, `н`];

///Строка ошибки времени компиляции - что, мол, облом
immutable(string) _notImplementedErrorMsg = `This conversion is not implemented: `;

/++
$(LOCALE_EN_US
	Template that returns real D language type of data field by enumerable value
	$(D_PARAM FieldT) of semantic field type
)

$(LOCALE_RU_RU
	Шаблон для возвращает реальный типа языка D для поля данных по перечислимому
	значению семантического типа поля $(D_PARAM FieldT)
)
+/
template DataFieldValueType(FieldType FieldT) 
{	static if( FieldT == FieldType.Int || FieldT == FieldType.Enum )
		alias int DataFieldValueType;
	else static if( FieldT == FieldType.Str )
		alias string DataFieldValueType;
	else static if( FieldT == FieldType.Bool )
		alias bool DataFieldValueType;
	else static if( FieldT == FieldType.IntKey )
		alias size_t DataFieldValueType;
	else static if( FieldT == FieldType.Date )
		alias std.datetime.Date DataFieldValueType;
	else
		static assert( 0, _notImplementedErrorMsg ~ FieldT.to!string );
}

/++
$(LOCALE_EN_US
	Function converts values from different real D types to another
	real D types but coresponding to semantical field types set
	by template argument $(D_PARAM FieldT)
)

$(LOCALE_RU_RU
	Преобразование из различных настоящих типов в другой реальный
	тип, который соотвествует семантическому типу поля,
	указанному в параметре шаблона FieldT
)
+/
auto fldConv(FieldType FieldT, S)( S value )
{	
	import std.traits;
// 	// целые числа --> DataFieldValueType!(FieldT)
// 	static if( isIntegral!(S) )
// 	{	with( FieldType ) {
// 		//Стандартное преобразование
// 		static if( FieldT == Int || FieldT == Str || FieldT == IntKey )
// 		{	return value.to!( DataFieldValueType!FieldT ); }
// 		else static if( FieldT == Bool ) //Для уверенности
// 		{	return ( value == 0 ) ? false : true ; }
// 		else
// 			static assert( 0, _notImplementedErrorMsg ~ typeof(value).stringof ~ " --> " ~ FieldT.to!string );
// 		}  //with( FieldType )
// 		assert(0);
// 	}
	
	// строки --> DataFieldValueType!(FieldT)
	//else 
	static if( isSomeString!(S) )
	{	with( FieldType ) {
		//Стандартное преобразование
		static if( FieldT == Int || FieldT == Str || FieldT == IntKey || FieldT == Enum )
		{	return value.to!( DataFieldValueType!FieldT ); }
		else static if( FieldT == Bool )
		{	import std.string;
			foreach(logVal; _logicTrueValues) 
				if ( logVal == toLower( strip( value ) ) ) 
					return true;
			
			foreach(logVal; _logicFalseValues) 
				if ( logVal == toLower( strip( value ) ) ) 
					return false;
			
			//TODO: Посмотреть, что делать с типами исключений в этом модуле
			throw new Exception( `Value "` ~ value.to!string ~ `" cannot be interpreted as boolean!!!` );
		}
		else static if( FieldT == Date )
		{	return std.datetime.Date.fromISOExtString(value); }
		else
			static assert( 0, _notImplementedErrorMsg ~ typeof(value).stringof ~ " --> " ~ FieldT.to!string );
		}  //with( FieldType )
		assert(0);
	}
	
	// bool --> DataFieldValueType!(FieldT)
// 	else static if( is( S : bool ) )
// 	{	with( FieldType ) {
// 		static if( FieldT == Int || FieldT == IntKey || FieldT == Enum )
// 		{	return ( value ) ? 1 : 0; }
// 		else static if( FieldT == Str )
// 		{	return ( value ) ? "да" : "нет"; }
// 		else static if( FieldT == Bool )
// 		{	return value; }
// 		else
// 			static assert( 0, _notImplementedErrorMsg ~ typeof(value).stringof ~ " --> " ~ FieldT.to!string );
// 		}  //with( FieldType )
// 		assert(0);
// 	}

}

/++
$(LOCALE_EN_US
	Returns true if $(D_PARAM FieldType) is key field type and false otherwise
)

$(LOCALE_RU_RU
	Возвращает true если $(D_PARAM FieldT) является типом ключевого поля или false в противном случае
)
+/
//Возвращает true если данный тип поля является типом ключевого поля
template isKeyFieldType(FieldType fieldType)
{	static if( fieldType == FieldType.IntKey )
		enum isKeyFieldType = true;
	else
		enum isKeyFieldType = false;
}

/++
$(LOCALE_EN_US
	Base interface for data field
)

$(LOCALE_RU_RU
	Базовый и нешаблонный интерфейс данных поля
)
+/
interface IBaseDataField
{
	/++
	$(LOCALE_EN_US Property returns type of data field)
	$(LOCALE_RU_RU Свойство возвращает тип поля данных)
	+/
	FieldType type() @property;

	/++
	$(LOCALE_EN_US Property returns number of rows in data field)
	$(LOCALE_RU_RU Свойство возвращает количество строк в поле данных)
	+/
	size_t length() @property;

	/++
	$(LOCALE_EN_US Property returns name of data field)
	$(LOCALE_RU_RU Свойство возвращает имя поля данных)
	+/
	string name() @property;

	/++
	$(LOCALE_EN_US Property is true if field value could be null an false if otherwise)
	$(LOCALE_RU_RU
		Свойство равно true, если значение поле может быть пустым
		(null) или равно false в противном случае
	)
	+/
	bool isNullable() @property;

	/++
	$(LOCALE_EN_US Property is true if allowed to write into field)
	$(LOCALE_RU_RU Свойство равно true, если разрешена запись в поле данных)
	+/
	bool isWriteable() @property;

	/++
	$(LOCALE_EN_US Function returns true if value of field with $(D_PARAM index) is null)
	$(LOCALE_RU_RU Функция возвращает true, если значение поля с номером $(D_PARAM index) пустое (null) )
	+/
	bool isNull(size_t index);

	/++
	$(LOCALE_EN_US
		Function returns string representation of field value at $(D_PARAM index).
		Parameter $(D_PARAM defaultValue) determines returned value if value
		by $(D_PARAM index) is null
	)
	$(LOCALE_RU_RU
		Функция возвращает строковое представление значения поля по номеру $(D_PARAM index)
		Параметр $(D_PARAM defaultValue) определяет возвращаемое значение,
		если возвращаемое значение пусто (null)
	)
	+/
	string getStr(size_t index, string defaultValue);

	
	JSONValue getStdJSONFormat();
	
		//Методы записи
// 	void setNull(size_t key); //Установить значение ячейки в null
// 	void isNullable(bool nullable) @property; //Установка возможности быть пустым
}

/++
$(LOCALE_EN_US
	Common template interface for data field
)

$(LOCALE_RU_RU
	Основной шаблонный интерфейс данных поля
)
+/
interface IDataField(FieldType FieldT) : IBaseDataField
{	
	alias DataFieldValueType!(FieldT) T;

	/++
	$(LOCALE_EN_US
		Function returns typed value of field by $(D_PARAM index).
		If value is null then behavior is undefined
	)
	$(LOCALE_RU_RU
		Функция возвращает значениt поля по номеру $(D_PARAM index)
		Если значение пусто (null), то поведение не определено
	)
	+/
	T get(size_t index);

	/++
	$(LOCALE_EN_US
		Function returns typed value of field by $(D_PARAM index).
		Parameter $(D_PARAM defaultValue) determines returned value if value
		by $(D_PARAM index) is null
	)
	$(LOCALE_RU_RU
		Функция возвращает значениt поля по номеру $(D_PARAM index)
		Параметр $(D_PARAM defaultValue) определяет возвращаемое значение,
		если значение поля пусто (null)
	)
	+/
 	T get(size_t index, T defaultValue);
 	
	static if( isKeyFieldType!(FieldT) )
	{
		/++
		$(LOCALE_EN_US Returns row index by record $(D_PARAM key))
		$(LOCALE_RU_RU Возвращает номер строки по ключу записи $(D_PARAM key))
		+/
		size_t getIndex(size_t key);

		/++
		$(LOCALE_EN_US Returns record key by row $(D_PARAM index))
		$(LOCALE_RU_RU Возвращает ключ записи по номеру строки $(D_PARAM index))
		+/
		size_t getKey(size_t index);
	}
	
	static if( FieldT == FieldType.Enum )
	{
		/++
		$(LOCALE_EN_US Returns format for enum field)
		$(LOCALE_RU_RU Возвращает формат для поля перечислимого типа)
		+/
		EnumFormat enumFormat();
	}
}




} //static if( isDatCtrlEnabled )