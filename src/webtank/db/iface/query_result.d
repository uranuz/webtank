module webtank.db.iface.query_result;

/++
$(LANG_EN Base interface for data base query result)
$(LANG_RU Базовый интерфейс для результата запроса к базе данных)
+/
interface IDBQueryResult
{	/+DBMSType type() @property; //Снова тип СУБД+/
	/++
	$(LANG_EN Property returns record count in result)
	$(LANG_RU Свойство возвращает количество записей в результате)
	+/
	size_t recordCount() @property inout;

	/++
	$(LANG_EN Property returns field count in result)
	$(LANG_RU Свойство возвращает количество полей в результате)
	+/
	size_t fieldCount() @property inout;

	/++
	$(LANG_EN Method clears object and frees resources of result)
	$(LANG_RU Метод очищает объект и освобождает ресурсы результата)
	+/
	void clear(); //Очистить объект

	/++
	$(LANG_EN
		Method returns name of field in result by field index $(D_PARAM index)
	)
	$(LANG_RU
		Метод возвращает имя поля в результате по индексу поля $(D_PARAM index)
	)
	+/
	string getFieldName(size_t index);

	/++
	$(LANG_EN
		Method returns index of field in result by field name $(D_PARAM name)
	)
	$(LANG_RU
		Метод возвращает номер поля в результате по имени поля $(D_PARAM name)
	)
	+/
	size_t getFieldIndex(string name);

	/++
	$(LANG_EN
		Method returns true if cell with field index $(D_PARAM fieldIndex) and
		record index $(D_PARAM recordIndex) is null or false otherwise
	)
	$(LANG_RU
		Метод возвращает true, если ячейка с номером поля $(D_PARAM fieldIndex)
		и номером записи $(D_PARAM recordIndex) является пустой (null) или
		false в противном случае
	)
	+/
	bool isNull(size_t fieldIndex, size_t recordIndex) inout;

	/++
	$(LANG_EN
		Method returns value of celll with field index $(D_PARAM fieldIndex) and
		record index $(D_PARAM recordIndex). If cell is null then behaviour is
		undefined
	)
	$(LANG_RU
		Метод возвращает значение ячейки с номером поля $(D_PARAM fieldIndex)
		и номером записи $(D_PARAM recordIndex). Если ячейка пуста (null), то
		поведение не определено
	)
	+/
	string get(size_t fieldIndex, size_t recordIndex) inout;

	/++
	$(LANG_EN
		Method returns value of celll with field index $(D_PARAM fieldIndex) and
		record index $(D_PARAM recordIndex). $(D_PARAM defaultValue) parameter
		sets return value when cell is null
	)
	$(LANG_RU
		Метод возвращает значение ячейки с номером поля $(D_PARAM fieldIndex)
		и номером записи $(D_PARAM recordIndex). Параметр метода
		$(D_PARAM defaultValue) задает возвращаемое значение, если ячейка пуста (null)
	)
	+/
	string get(size_t fieldIndex, size_t recordIndex, string defaultValue) inout;
}