module webtank.datctrl.consts;

/// Названия полей JSON-объектов, в форме которых представляются (сериализуются) данные при передаче
enum SrlField
{
	/// Номер ключевого поля в рекорде/ рекордсете
	keyFieldIndex = `kfi`,

	/// Тип объекта: дата, запись, перечислимое и т.п.
	type = `t`,

	/// Название поля, либо еще какой-то сущности
	name = `n`,

	/// Формат записи, набора записей
	format = `f`,

	/// Данные записи, набора записей
	data = `d`,

	/// Формат для значения перечислимого типа
	enum_ = `enum`,

	/// Размер значения (например, для числел)
	size = `sz`,

	/// Тип значения в языке D
	dLangType = `dt`,

	/// Тип значения в виде строковой константы
	valueType = `vt`,

	/// Тип значения ключа
	keyType = `kt`
}

/// Типы сериализуемых сущностей
enum SrlEntityType
{
	/// Набор записей
	recordSet = `recordset`,
	/// Запись
	record = `record`,
	/// Перечислимое
	enum_ = `enum`,
	/// Дата
	date = `date`,
	/// Время
	time = `time`,
	/// Дата и время
	dateTime = `dateTime`
}

/// Типы полей в сериализуемых данных
enum SrlFieldType
{
	unknown = `<unknown>`,
	void_ = `void`,
	boolean = `bool`,
	integer = `int`,
	floating = `float`,
	string = `str`,
	array = `array`,
	assocArray = `assocArray`,
	date = `date`,
	time = `time`,
	dateTime = `dateTime`
}