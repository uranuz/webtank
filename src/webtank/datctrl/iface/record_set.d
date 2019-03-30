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
	$(LANG_EN Index operator for getting record by $(D_PARAM recordIndex))
	$(LANG_RU Оператор индексирования для получения записи по номеру $(D_PARAM recordIndex))
	+/
	IBaseRecord opIndex(size_t recordIndex);

	/++
	$(LANG_EN Returns record by $(D_PARAM recordIndex))
	$(LANG_RU Возвращает запись на позиции $(D_PARAM recordIndex))
	+/
	IBaseRecord getRecordAt(size_t recordIndex);

	/++
	$(LANG_EN
		Returns string representation of cell with field name $(D_PARAM fieldName) and record index $(D_PARAM recordIndex)
	)
	$(LANG_RU
		Возвращает строковое представление ячейки с именем поля $(D_PARAM fieldName)
		и порядковым номером записи $(D_PARAM recordIndex).
	)
	+/
	string getStr(string fieldName, size_t recordIndex);

	/++
	$(LANG_EN
		Returns string representation of cell with field name $(D_PARAM fieldName)
		and record index $(D_PARAM recordIndex). If value of cell is empty then
		it return value specified by $(D_PARAM defaultValue) parameter, which will
		have null value if parameter is missed.
	)
	$(LANG_RU
		Возвращает строковое представление ячейки с именем поля $(D_PARAM fieldName)
		и порядковым номером записи $(D_PARAM recordIndex). Если значение
		ячейки пустое (null), тогда функция вернет значение задаваемое параметром
		$(D_PARAM defaultValue). Этот параметр будет иметь значение null, если параметр опущен
	)
	+/
	string getStr(string fieldName, size_t recordIndex, string defaultValue);

	/++
		$(LANG_EN Returns index of field considered as primary key field)
		$(LANG_RU Возвращает номер поля рассматриваемого как первичный ключ)
	+/
	size_t keyFieldIndex() @property;

	/++
	$(LANG_EN
		Returns true if cell with field name $(D_PARAM fieldName) and record
		index $(D_PARAM recordIndex) is null or false otherwise
	)
	$(LANG_RU
		Возвращает true, если ячейка с именем поля $(D_PARAM fieldName) и
		номером записи в наборе $(D_PARAM recordIndex) пуста (null). В противном
		случае возвращает false
	)
	+/
	bool isNull(string fieldName, size_t recordIndex);

	/++
	$(LANG_EN
		Returns true if cell with field name $(D_PARAM fieldName) can
		be null or false otherwise
	)
	$(LANG_RU
		Возвращает true, если ячейка с именем поля $(D_PARAM fieldName)
		может быть пустой (null). В противном случае возвращает false
	)
	+/
	bool isNullable(string fieldName);

	bool isWriteable(string fieldName);

	/++
	$(LANG_EN Returns number of records in set)
	$(LANG_RU Возвращает количество записей в наборе)
	+/
	size_t length() @property inout;

	/++
	$(LANG_EN Returns number of data fields in record set)
	$(LANG_RU Возвращает количество полей данных в наборе)
	+/
	size_t fieldCount() @property inout;

	import std.json: JSONValue;

	/++
	$(LANG_EN Serializes data of record at $(D_PARAM index) into std.json)
	$(LANG_RU Сериализует данные записи под номером $(D_PARAM index) в std.json)
	+/
	JSONValue getStdJSONData(size_t index) inout;

	/++
	$(LANG_EN Serializes format of record set into std.json)
	$(LANG_RU Сериализует формат набора записей в std.json)
	+/
	JSONValue getStdJSONFormat() inout;

	/++
	$(LANG_EN Serializes format and data of record set into std.json)
	$(LANG_RU Сериализует формат и данные набора данных в std.json)
	+/
	JSONValue toStdJSON() inout;

	/++
	$(LANG_EN Operator for getting range over record set in foreach loop)
	$(LANG_RU Оператор для получения range (диапазона для обхода) в цикле foreach)
	+/
	IRecordSetRange opSlice();

	IBaseRecordSet opSlice(size_t begin, size_t end);

	/++
	$(LANG_EN
		Returns record index by string representation of key $(D_PARAM recordKey).
		Intended for internal library usage
	)
	$(LANG_RU
		Возвращает номер записи по строковому представлению ключа $(D_PARAM recordKey).
		Предназанчено для внутреннего использования
	)
	+/
	size_t getIndexByStringKey(string recordKey);

	/++
	$(LANG_EN
		Returns record index by link on cursor-record.
		Intended for internal library usage
	)
	$(LANG_RU
		Возвращает номер записи по записи-курсору.
		Предназанчено для внутреннего использования
	)
	+/
	size_t getIndexByCursor(IBaseRecord cursor);
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
		IBaseWriteableRecord getRecordAt(size_t recordIndex);
		IWriteableRecordSetRange opSlice();
	}
}

} //static if( isDatCtrlEnabled )
