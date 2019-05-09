module webtank.db.database_field;

import std.json, std.conv, std.traits, std.datetime;

import webtank.datctrl.iface.data_field;
import webtank.db.database;
import webtank.datctrl.record_format;
import webtank.datctrl.enum_format;

import webtank.common.conv;
import std.exception: enforce;

///Класс ключевого поля
class DatabaseField(FormatT) : IDataField!( FormatT )
{
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType);

protected: ///ВНУТРЕННИЕ ПОЛЯ КЛАССА
	IDBQueryResult _queryResult;
	immutable(size_t) _fieldIndex;
	immutable(string) _name;
	immutable(bool) _isNullable;

	static if( isEnumFormat!(FormatType) ) {
		FormatType _enumFormat;
	}

public:

	static if( isEnumFormat!(FormatType) )
	{
		this( IDBQueryResult queryResult,
			size_t fieldIndex,
			string fieldName, bool isNullable,
			FormatType enumFormat
		) {
			_queryResult = queryResult;
			_fieldIndex = fieldIndex;
			_name = fieldName;
			_isNullable = isNullable;
			_enumFormat = enumFormat;
		}

		///Возвращает формат значения перечислимого типа
		override inout(FormatType) enumFormat() inout {
			return _enumFormat;
		}
	}
	else
	{
		this( IDBQueryResult queryResult, size_t fieldIndex, string fieldName, bool isNullable )
		{
			_queryResult = queryResult;
			_fieldIndex = fieldIndex;
			_name = fieldName;
			_isNullable = isNullable;
		}
	}

	override { //Переопределяем интерфейсные методы
		///Возвращает тип поля
		//FieldType type()
		//{	return FieldT; }

		///Возвращает количество записей для поля
		size_t length() @property inout {
			return _queryResult.recordCount;
		}

		string name() @property inout {
			return _name;
		}

		///Возвращает true, если поле может быть пустым и false - иначе
		bool isNullable() @property inout {
			return _isNullable;
		}

		///Возвращает false, поскольку поле не записываемое
		bool isWriteable() @property inout {
			return false; //Поле только для чтения из БД
		}

		///Возвращает true, если поле пустое или false - иначе
		bool isNull(size_t index) inout
		{
			import std.conv;
			enforce( index < _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index)
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			return
				( _isNullable?
				_queryResult.isNull( _fieldIndex, index )
				: false );
		}

		import webtank.datctrl.common;
		mixin GetStdJSONFieldFormatImpl;
		mixin GetStdJSONFieldValueImpl;

		///Получение данных из поля по порядковому номеру index
		inout(ValueType) get(size_t index) inout
		{
			import std.conv: text;
			enforce( index < _queryResult.recordCount, "Field index '" ~ index.text
				~ "' is out of bounds, because record count is '" ~ _queryResult.recordCount.text ~ "'!!!" );
			try {
				return cast(inout) _queryResult.get(_fieldIndex, index).conv!ValueType;
			} catch(ConvException ex) {
				throw new ConvException(
					`Exception during parsing value for field with name "` ~ name
					~ `" at index: ` ~ index.text ~ `. Error msg:` ~ ex.to!string);
			}
		}

		///Получение данных из поля по порядковому номеру index
		///Возвращает defaultValue, если значение поля пустое
		inout(ValueType) get(size_t index, ValueType defaultValue) inout
		{
			import std.conv: to;
			enforce( index < _queryResult.recordCount, "Field index '" ~ index.text
				~ "' is out of bounds, because record count is '" ~ _queryResult.recordCount.text ~ "'!!!" );
			try {
				return cast(inout)( isNull(index) ? defaultValue: _queryResult.get(_fieldIndex, index).conv!ValueType );
			} catch(ConvException ex) {
				throw new ConvException(
					`Exception during parsing value for field with name "` ~ name
					~ `" at index: ` ~ index.text ~ `. Error msg:` ~ ex.to!string);
			}
		}

		///Получает строковое представление данных
		string getStr(size_t index)
		{
			enforce( index < _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index)
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );

			static if( isEnumFormat!(FormatType) )
			{
				if( isNull(index) ) {
					return null;
				} else {
					try {
						return _enumFormat.getStr( _queryResult.get(_fieldIndex, index).conv!ValueType );
					} catch(ConvException ex) {
						throw new ConvException(
							`Exception during parsing value for field with name "` ~ name
							~ `" at index: ` ~ index.to!string ~ `. Error msg:` ~ ex.to!string);
					}
				}
			}
			else
			{
				//TODO: добавить проверку на соответствие значения базовому типу поля
				return _queryResult.get(_fieldIndex, index).to!string;
			}
		}

		///Получает строковое представление данных
		string getStr(size_t index, string defaultValue)
		{
			enforce( index < _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index)
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );

			if( isNull(index) ) {
				return defaultValue;
			}
			else
			{
				static if( isEnumFormat!(FormatType) ) {
					try {
						return _enumFormat.getStr( _queryResult.get(_fieldIndex, index).conv!ValueType );
					} catch(ConvException ex) {
						throw new ConvException(
							`Exception during parsing value for field with name "` ~ name
							~ `" at index: ` ~ index.to!string ~ `. Error msg:` ~ ex.to!string);
					}
				} else {
					//TODO: добавить проверку на соответствие значения базовому типу поля
					return _queryResult.get(_fieldIndex, index).to!string;
				}
			}
		}
	} //override
}

IBaseDataField[] makePostgreSQLDataFields(RecordFormatType)(IDBQueryResult queryResult, RecordFormatType format)
{
	import std.exception: enforce;
	import std.conv: text;
	enforce(queryResult !is null, `Expectes instance of IDBQueryResult`);
	enforce(
		RecordFormatType.tupleOfNames.length <= queryResult.fieldCount,
		`Expected at least ` ~ RecordFormatType.tupleOfNames.length.text
		~ ` fields in database query result, but got ` ~ queryResult.fieldCount.text);
	IBaseDataField[] dataFields;
	foreach( fieldName; RecordFormatType.tupleOfNames )
	{
		alias FieldFormatDecl = RecordFormatType.getFieldFormatDecl!(fieldName);
		alias CurrFieldT = DatabaseField!(FieldFormatDecl);
		alias fieldIndex = RecordFormatType.getFieldIndex!(fieldName);

		bool isNullable = format.nullableFlags.get(fieldName, true);

		static if( isEnumFormat!(FieldFormatDecl) )
		{
			alias enumFieldIndex = RecordFormatType.getEnumFormatIndex!(fieldName);
			dataFields ~= new CurrFieldT(queryResult, fieldIndex, fieldName, isNullable,  format.enumFormats[enumFieldIndex]);
		}
		else {
			dataFields ~= new CurrFieldT(queryResult, fieldIndex, fieldName, isNullable);
		}
	}
	return dataFields;
}


unittest
{
	import webtank.datctrl.iface.record_set;
	import webtank.datctrl.record_set;
	import webtank.datctrl.typed_record_set;

	auto recFormat = RecordFormat!(
		PrimaryKey!(size_t), "num",
		string, "name"
	)();
	IDBQueryResult pgResult;
	IBaseDataField[] dataFields = makePostgreSQLDataFields(pgResult, recFormat);
	auto baseRS = new RecordSet(dataFields);
	auto rs = TypedRecordSet!(typeof(recFormat), IBaseRecordSet)(baseRS);
}