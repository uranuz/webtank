module webtank.datctrl.iface.data_field;

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

struct PrimaryKey(T) {
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
	static if( isPrimaryKeyFormat!(FormatType) ) {
		alias DataFieldValueType = DataFieldValueType!(FormatType.BaseDecl);
	} else static if( isEnumFormat!(FormatType) ) {
		alias DataFieldValueType = FormatType.ValueType;
	}	else static if( is(FormatType) ) {
		alias DataFieldValueType = FormatType;
	} else {
		static assert( 0, FormatType.stringof ~ " is not valid D type!!!" );
	}
}


/++
$(LOCALE_EN_US Base interface for data field)
$(LOCALE_RU_RU Базовый и нешаблонный интерфейс данных поля)
+/
interface IBaseDataField
{
	/++
	$(LOCALE_EN_US Returns number of rows in data field)
	$(LOCALE_RU_RU Возвращает количество строк в поле данных)
	+/
	size_t length() @property;

	/++
	$(LOCALE_EN_US Returns name of data field)
	$(LOCALE_RU_RU Возвращает имя поля данных)
	+/
	string name() @property;

	/++
	$(LOCALE_EN_US Returns true if field value could be null or false otherwise)
	$(LOCALE_RU_RU	Возвращает true, если значение поле может быть пустым	(null) иначе равно false)
	+/
	bool isNullable() @property;

	/++
	$(LOCALE_EN_US Returns true if allowed to write into field)
	$(LOCALE_RU_RU Возвращает true, если разрешена запись в поле данных)
	+/
	bool isWriteable() @property;

	/++
	$(LOCALE_EN_US Returns true if value of field with $(D_PARAM index) is null)
	$(LOCALE_RU_RU Возвращает true, если значение поля с номером $(D_PARAM index) пустое (null) )
	+/
	bool isNull(size_t index);

	string getStr(size_t index);

	/++
	$(LOCALE_EN_US
		Returns string representation of field value at $(D_PARAM index).
		Parameter $(D_PARAM defaultValue) determines returned value if value by $(D_PARAM index) is null
	)
	$(LOCALE_RU_RU
		Возвращает строковое представление значения поля по номеру $(D_PARAM index)
		Параметр $(D_PARAM defaultValue) определяет возвращаемое значение, если возвращаемое значение пусто (null)
	)
	+/
	string getStr(size_t index, string defaultValue);

	/++
	$(LOCALE_EN_US Returns format of field in JSON representation)
	$(LOCALE_RU_RU Возвращает формат поля в представлении JSON)
	+/
	JSONValue getStdJSONFormat();

	/++
	$(LOCALE_EN_US Returns value of cell with $(D_PARAM index) in JSON format)
	$(LOCALE_RU_RU Возвращает значение ячейки с номером $(D_PARAM index) в виде JSON)
	+/
	JSONValue getStdJSONValue(size_t index);
}


interface IBaseWriteableDataField: IBaseDataField
{
	/++
	$(LOCALE_EN_US Make cell with $(D_PARAM index) null)
	$(LOCALE_RU_RU Обнуляет занчение ячейки с номером $(D_PARAM index))
	+/
	void nullify(size_t index);

	alias isNullable = IBaseDataField.isNullable;
	/++
	$(LOCALE_EN_US Set field ability to be null)
	$(LOCALE_RU_RU Задает возможность для свойства иметь значение null)
	+/
	void isNullable(bool value) @property;

	/++
	$(LOCALE_EN_US Inserts $(D_PARAM count) field .init values at $(D_PARAM index)(value will be appended to the end if param is not set))
	$(LOCALE_RU_RU Вставляет $(D_PARAM count) начальных значений в позицию $(D_PARAM index)(будет добавлено в конец, если параметр не задан))
	+/
	void addItems(size_t count, size_t index = size_t.max);

	void fromStdJSONValue(JSONValue jValue, size_t index);
}

/++
$(LOCALE_EN_US Common template interface for data field)
$(LOCALE_RU_RU Основной шаблонный интерфейс данных поля)
+/
interface IDataField(FormatType) : IBaseDataField
{
	alias ValueType = DataFieldValueType!(FormatType);

	/++
	$(LOCALE_EN_US
		Function returns typed value of field by $(D_PARAM index).
		If value is null then behavior is undefined
	)
	$(LOCALE_RU_RU
		Функция возвращает значение поля по номеру $(D_PARAM index).
		Если значение пусто (null), то поведение не определено
	)
	+/
	ValueType get(size_t index);

	/++
	$(LOCALE_EN_US
		Function returns typed value of field by $(D_PARAM index).
		Parameter $(D_PARAM defaultValue) determines returned value if value by $(D_PARAM index) is null
	)
	$(LOCALE_RU_RU
		Функция возвращает значение поля по номеру $(D_PARAM index)
		Параметр $(D_PARAM defaultValue) определяет возвращаемое значение, если значение поля пусто (null)
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

interface IWriteableDataField(FormatType): IDataField!(FormatType), IBaseWriteableDataField
{
	alias ValueType = DataFieldValueType!(FormatType);
	/++
		$(LOCALE_EN_US Set value of cell at $(D_PARAM index) with $(D_PARAM value))
		$(LOCALE_RU_RU Устанавливает значение ячейки $(D_PARAM value) с порядковым номером $(D_PARAM index))
	+/
	void set(ValueType value, size_t index);

	/++
		$(LOCALE_EN_US Add $(D_PARAM values) at $(D_PARAM index))
		$(LOCALE_RU_RU Добавляет значения $(D_PARAM values) в позицию $(D_PARAM index))
	+/
	void addItems(ValueType[] values, size_t index = size_t.max);
}

} //static if( isDatCtrlEnabled )
