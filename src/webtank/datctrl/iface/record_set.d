module webtank.datctrl.iface.record_set;

import webtank._version;

static if( isDatCtrlEnabled ) {

import webtank.datctrl.iface.data_field;
import webtank.datctrl.iface.record;
import std.range.interfaces: InputRange;

alias IRecordSetRange = InputRange!IBaseRecord;

interface IBaseRecordSet
{
	IBaseDataField getField(string fieldName);

	/++
	$(LOCALE_EN_US Index operator for getting record by $(D_PARAM recordIndex))
	$(LOCALE_RU_RU Оператор индексирования для получения записи по номеру $(D_PARAM recordIndex))
	+/
	IBaseRecord opIndex(size_t recordIndex);

	/++
	$(LOCALE_EN_US Returns record by $(D_PARAM recordIndex))
	$(LOCALE_RU_RU Возвращает запись на позиции $(D_PARAM recordIndex))
	+/
	IBaseRecord getRecord(size_t recordIndex);

	/++
	$(LOCALE_EN_US
		Returns string representation of cell with field name $(D_PARAM fieldName) and record index $(D_PARAM recordIndex)
	)
	$(LOCALE_RU_RU
		Возвращает строковое представление ячейки с именем поля $(D_PARAM fieldName)
		и порядковым номером записи $(D_PARAM recordIndex).
	)
	+/
	string getStr(string fieldName, size_t recordIndex);

	/++
	$(LOCALE_EN_US
		Returns string representation of cell with field name $(D_PARAM fieldName)
		and record index $(D_PARAM recordIndex). If value of cell is empty then
		it return value specified by $(D_PARAM defaultValue) parameter, which will
		have null value if parameter is missed.
	)
	$(LOCALE_RU_RU
		Возвращает строковое представление ячейки с именем поля $(D_PARAM fieldName)
		и порядковым номером записи $(D_PARAM recordIndex). Если значение
		ячейки пустое (null), тогда функция вернет значение задаваемое параметром
		$(D_PARAM defaultValue). Этот параметр будет иметь значение null, если параметр опущен
	)
	+/
	string getStr(string fieldName, size_t recordIndex, string defaultValue);
	
	/++
		$(LOCALE_EN_US Returns index of field considered as primary key field)
		$(LOCALE_RU_RU Возвращает номер поля рассматриваемого как первичный ключ)
	+/
	size_t keyFieldIndex() @property;

	/++
	$(LOCALE_EN_US
		Returns true if cell with field name $(D_PARAM fieldName) and record
		index $(D_PARAM recordIndex) is null or false otherwise
	)
	$(LOCALE_RU_RU
		Возвращает true, если ячейка с именем поля $(D_PARAM fieldName) и
		номером записи в наборе $(D_PARAM recordIndex) пуста (null). В противном
		случае возвращает false
	)
	+/
	bool isNull(string fieldName, size_t recordIndex);

	/++
	$(LOCALE_EN_US
		Returns true if cell with field name $(D_PARAM fieldName) can
		be null or false otherwise
	)
	$(LOCALE_RU_RU
		Возвращает true, если ячейка с именем поля $(D_PARAM fieldName)
		может быть пустой (null). В противном случае возвращает false
	)
	+/
	bool isNullable(string fieldName);

	bool isWriteable(string fieldName);

	/++
	$(LOCALE_EN_US Returns number of records in set)
	$(LOCALE_RU_RU Возвращает количество записей в наборе)
	+/
	size_t length() @property;

	/++
	$(LOCALE_EN_US Returns number of data fields in record set)
	$(LOCALE_RU_RU Возвращает количество полей данных в наборе)
	+/
	size_t fieldCount() @property;

	import std.json: JSONValue;

	/++
	$(LOCALE_EN_US Serializes data of record at $(D_PARAM index) into std.json)
	$(LOCALE_RU_RU Сериализует данные записи под номером $(D_PARAM index) в std.json)
	+/
	JSONValue getStdJSONData(size_t index);

	/++
	$(LOCALE_EN_US Serializes format of record set into std.json)
	$(LOCALE_RU_RU Сериализует формат набора записей в std.json)
	+/
	JSONValue getStdJSONFormat();

	/++
	$(LOCALE_EN_US Serializes format and data of record set into std.json)
	$(LOCALE_RU_RU Сериализует формат и данные набора данных в std.json)
	+/
	JSONValue toStdJSON();

	/++
	$(LOCALE_EN_US Operator for getting range over record set in foreach loop)
	$(LOCALE_RU_RU Оператор для получения range (диапазона для обхода) в цикле foreach)
	+/
	IRecordSetRange opSlice();

	/++
	$(LOCALE_EN_US
		Returns record index by string representation of key $(D_PARAM recordKey).
		Intended for internal library usage
	)
	$(LOCALE_RU_RU
		Возвращает номер записи по строковому представлению ключа $(D_PARAM recordKey).
		Предназанчено для внутреннего использования
	)
	+/
	size_t getIndexByStringKey(string recordKey);
}

// В основном этот интерфейс - это хак, чтобы сделать ковариантный интерфейс range с записываемым элементом
interface IWriteableRecordSetRange: IRecordSetRange
{
	override @property IBaseWriteableRecord front();
	override IBaseWriteableRecord moveFront();

	int opApply(scope int delegate(IBaseWriteableRecord));
	int opApply(scope int delegate(size_t, IBaseWriteableRecord));
}

interface IBaseWriteableRecordSet: IBaseRecordSet
{
	void nullify(string fieldName, size_t recordIndex);
	void setNullable(string fieldName, bool value);
	void addItems(size_t count, size_t index = size_t.max);
	void addItems(IBaseWriteableRecord[] records, size_t index = size_t.max);

	override {
		// Ковариантные переопределения методов для записываемых типов
		IBaseWriteableDataField getField(string fieldName);
		IBaseWriteableRecord opIndex(size_t recordIndex);
		IBaseWriteableRecord getRecord(size_t recordIndex);
		IWriteableRecordSetRange opSlice();
	}
}

} //static if( isDatCtrlEnabled )
