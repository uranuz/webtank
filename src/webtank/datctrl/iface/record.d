module webtank.datctrl.iface.record;

import webtank._version;

static if( isDatCtrlEnabled ) {

import webtank.datctrl.iface.data_field;

/++
$(LOCALE_EN_US Base interface for data record)
$(LOCALE_RU_RU Базовый интерфейс для записи данных)
+/
interface IBaseRecord
{
	/++
	$(LOCALE_EN_US
		Returns data field with name $(D_PARAM fieldName) of this record.
		Mostly intended for internal use in implementation
	)
	$(LOCALE_RU_RU
		Возвращает поле данных с именем $(D_PARAM fieldName) для этой записи.
		Предназначено в основном для внутреннего использования в реализации
	)
	+/
	IBaseDataField getField(string fieldName);

	/++
	$(LOCALE_EN_US
		Returns index of record in data source where record comes from (if source exists) or 0.
		Mostly intended for internal use in implementation
	)
	$(LOCALE_RU_RU
		Возвращает номер записи в исходном источнике данных, откуда пришла запись (если есть источник) или 0.
		Предназначено в основном для внутреннего использования в реализации
	)
	+/
	size_t recordIndex() @property;

	/++
	$(LOCALE_EN_US Returns string representation of value for field with name $(D_PARAM fieldName))
	$(LOCALE_RU_RU Функция возвращает строковое представление значения для поля с именем $(D_PARAM fieldName))
	+/
	string getStr(string fieldName);

	/++
	$(LOCALE_EN_US Returns string representation of value for field
		with name $(D_PARAM fieldName). Parameter $(D_PARAM defaultValue) determines
		returned value if value by $(D_PARAM index) is null
	)
	$(LOCALE_RU_RU Возвращает строковое представление значения для поля
		с именем $(D_PARAM fieldName). Параметр $(D_PARAM defaultValue) определяет
		возвращаемое значение, если возвращаемое значение пусто (null)
	)
	+/
	string getStr(string fieldName, string defaultValue);

	/++
	$(LOCALE_EN_US Returns true if value for field with name $(D_PARAM fieldName)
		is null or returns false otherwise if it's not empty. 
	)
	$(LOCALE_RU_RU Возвращает true, если значения для поля с именем $(D_PARAM fieldName)
		является пустым (null) или false, если значение не пустое
	)
	+/
	bool isNull(string fieldName);

	/++
	$(LOCALE_EN_US Returns true if value for field with name $(D_PARAM fieldName)
		could be null or returns false if it can't be null
	)
	$(LOCALE_RU_RU Возвращает true, если значения для поля с именем $(D_PARAM fieldName)
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

	import std.json: JSONValue;

	/++
	$(LOCALE_EN_US Returns number of fields in record)
	$(LOCALE_RU_RU Возвращает количество полей в записи)
	+/
	JSONValue toStdJSON();

	/++
		$(LOCALE_EN_US Returns index of field considered as primary key field)
		$(LOCALE_RU_RU Возвращает номер поля рассматриваемого как первичный ключ)
	+/
	size_t keyFieldIndex() @property;
}

interface IBaseWriteableRecord: IBaseRecord
{
	override IBaseWriteableDataField getField(string fieldName);

	void nullify(string fieldName);
	void setNullable(string fieldName, bool value);
}

} //static if( isDatCtrlEnabled )
