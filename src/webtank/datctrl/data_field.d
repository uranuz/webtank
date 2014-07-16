module webtank.datctrl.data_field;

import webtank._version;

static if( isDatCtrlEnabled ) {

import std.array, std.conv, std.json, std.datetime, std.traits;

import webtank.datctrl.enum_format;


///В шаблоне хранится соответсвие между именем и типом поля
template FieldSpec( T, string s = null )
{	
	alias FormatDecl = T;
	alias ValueType = DataFieldValueType!(T);
	alias name = s;
}

struct PrimaryKey(T)
{
	alias BaseDecl = T;
}

/++
$(LOCALE_EN_US
	Returns true if $(D_PARAM FieldType) is key field type and false otherwise
)

$(LOCALE_RU_RU
	Возвращает true если $(D_PARAM FieldT) является типом ключевого поля или false в противном случае
)
+/

alias isPrimaryKeyFormat(T...) =  isInstanceOf!(PrimaryKey, T[0]);

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
template DataFieldValueType(FormatType) 
{	
	static if( isPrimaryKeyFormat!(FormatType) )
	{
		alias DataFieldValueType = DataFieldValueType!(FormatType.BaseDecl);
	}
	else static if( isEnumFormat!(FormatType) )
	{
		alias DataFieldValueType = FormatType.ValueType;
	}
	else static if( is(FormatType) )
	{
		alias DataFieldValueType = FormatType;
	}
	else
		static assert( 0, FormatType.stringof ~ " is not valid D type!!!" );
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
	//FieldType type() @property;

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
	
	string getStr(size_t index);
	
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


interface IBaseWriteableDataField
{
	void nullify(size_t index);
	void setNullable(size_t index, bool value);
}

/++
$(LOCALE_EN_US
	Common template interface for data field
)

$(LOCALE_RU_RU
	Основной шаблонный интерфейс данных поля
)
+/
interface IDataField(FormatT) : IBaseDataField
{	
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType);
	
	/++
	$(LOCALE_EN_US
		Function returns typed value of field by $(D_PARAM index).
		If value is null then behavior is undefined
	)
	$(LOCALE_RU_RU
		Функция возвращает значение поля по номеру $(D_PARAM index)
		Если значение пусто (null), то поведение не определено
	)
	+/
	ValueType get(size_t index);

	/++
	$(LOCALE_EN_US
		Function returns typed value of field by $(D_PARAM index).
		Parameter $(D_PARAM defaultValue) determines returned value if value
		by $(D_PARAM index) is null
	)
	$(LOCALE_RU_RU
		Функция возвращает значение поля по номеру $(D_PARAM index)
		Параметр $(D_PARAM defaultValue) определяет возвращаемое значение,
		если значение поля пусто (null)
	)
	+/
	ValueType get(size_t index, ValueType defaultValue);

	static if( isEnumFormat!(FormatType) )
	{
		/++
		$(LOCALE_EN_US Returns format for enum field)
		$(LOCALE_RU_RU Возвращает формат для поля перечислимого типа)
		+/
		FormatType enumFormat();
	}
}

interface IWriteableDataField(alias FormatT): IDataField!(FormatT), IBaseWriteableDataField
{
	void set(size_t index, ValueType value);

}


class WriteableField(alias FormatT): IWriteableDataField!(FormatT)
{
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType);

protected:
	ValueType[] _values;
	bool[] _nullFlags;
	string _name;
	bool _isNullable;
	
	static if( isEnumFormat!(FormatType) )
	{
		this( 
			ValueType[] values,
			bool[] nullFlags,
			string fieldName, bool isNullable,
			FormatType enumFormat
		)
		{	_values = values;
			_nullFlags = nullFlags;
			_name = fieldName;
			_isNullable = isNullable;
			_enumFormat = enumFormat;
		}
		
		FormatType _enumFormat;
	}
	
	this( 
		ValueType[] values,
		bool[] nullFlags,
		string fieldName, bool isNullable
	)
	{	_values = values;
		_nullFlags = nullFlags;
		_name = fieldName;
		_isNullable = isNullable;
	}
	
	
	override
	{
		size_t length() @property
		{
			return _values.length;
		}
	
		string name() @property
		{
			return _name;
		}
		
		bool isNullable() @property
		{
			return _isNullable;
		}
		
		bool isWriteable() @property
		{
			return true;
		}
		
		bool isNull(size_t index)
		{
			return isNullable ? ( _nullFlags[index] ) : false;
		}
	
		string getStr(size_t index)
		{
			return isNull ? null : _values[index].to!string;
		}
		
		string getStr(size_t index, string defaultValue)
		{
			return isNull ? defaultValue : _values[index].to!string;
		}
		
		JSONValue getStdJSONFormat()
		{
		
		}
		
		ValueType get(size_t index)
		{
			return _values[index];
		}
		
		ValueType get(size_t index, ValueType defaultValue)
		{
			return isNull ? defaultValue : _values[index];
		}

		static if( isEnumFormat!(FormatType) )
		{
			FormatType enumFormat()
			{
				return _enumFormat;
			}
		}
		
		void set(size_t index, ValueType value)
		{
			_nullFlags[index] = false;
			_values[index] = value;
		}
		
		void nullify(size_t index)
		{
			_nullFlags[index] = true;
			_values[index] = ValueType.init;
		}
		
		void setNullable(bool value) @property
		{
			_isNullable = value;
		}

	
	} //override

}



} //static if( isDatCtrlEnabled )
