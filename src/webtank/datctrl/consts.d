module webtank.datctrl.consts;

enum WT_KEY_FIELD_INDEX = `kfi`; // Поле с номером ключевого поля в рекорде/ рекордсете
enum WT_TYPE_FIELD = `t`; // Поле, содержащее тип объекта: дата, запись, перечислимое и т.п.
enum WT_NAME_FIELD = `n`; // Название сужности
enum WT_FORMAT_FIELD = `f`; // Формат записи, набора записей
enum WT_DATA_FIELD = `d`; // Данные записи, набора записей
enum WT_ENUM_FIELD = `enum`; // Формат перечислимого типа
enum WT_SIZE_FIELD = `sz`; // Размер значения
enum WT_DLANG_TYPE_FIELD = `dt`; // Тип значения в языке D
enum WT_VALUE_TYPE_FIELD = `vt`; // Тип значения
enum WT_KEY_TYPE_FIELD = `kt`; // Тип ключа

enum WT_TYPE_RECORDSET = `recordset`; // Тип - набор записей
enum WT_TYPE_RECORD = `record`; // Тип - запись
enum WT_TYPE_ENUM = `enum`; // Тип - перечислимое
enum WT_TYPE_DATE = `date`; // Тип - дата
enum WT_TYPE_DATETIME = `dateTime`; // Тип - дата/время
