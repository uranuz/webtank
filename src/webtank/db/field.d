module webtank.db.field;

import webtank.datctrl.iface.data_field: IDataField, IBaseDataField;
import webtank.db.iface.query_result: IDBQueryResult;


/// Поле данных, работющее на чтение напрямую с результатом запроса из базы данных
class DatabaseField(FormatT): IDataField!FormatT
{
	import webtank.common.conv: conv;
	import std.exception: enforce;

	import std.json, std.conv, std.traits, std.datetime;

	import webtank.datctrl.iface.data_field;
	import webtank.db;
	import webtank.datctrl.record_format;
	import webtank.datctrl.enum_format;
	
	
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType);

protected: ///ВНУТРЕННИЕ ПОЛЯ КЛАССА
	IDBQueryResult _queryResult;
	immutable(size_t) _fieldIndex;
	immutable(string) _name;

	static if( isEnumFormat!(FormatType) ) {
		FormatType _enumFormat;
	}

public:

	static if( isEnumFormat!(FormatType) )
	{
		this( IDBQueryResult queryResult,
			size_t fieldIndex,
			string fieldName,
			FormatType enumFormat
		) {
			_queryResult = queryResult;
			_fieldIndex = fieldIndex;
			_name = fieldName;
			_enumFormat = enumFormat;
		}

		///Возвращает формат значения перечислимого типа
		override inout(FormatType) enumFormat() inout {
			return _enumFormat;
		}
	}
	else
	{
		this( IDBQueryResult queryResult, size_t fieldIndex, string fieldName )
		{
			_queryResult = queryResult;
			_fieldIndex = fieldIndex;
			_name = fieldName;
		}
	}

	override { //Переопределяем интерфейсные методы
		///Возвращает количество записей для поля
		size_t length() @property inout {
			return _queryResult.recordCount;
		}

		string name() @property inout {
			return _name;
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
			return _queryResult.isNull(_fieldIndex, index);
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

IBaseDataField[] makeDataFields(RecordFormatType)(IDBQueryResult queryResult, RecordFormatType format)
{
	import webtank.datctrl.memory_data_field: MemoryDataField;
	import webtank.datctrl.enum_format: isEnumFormat;
	import webtank.common.optional: Optional;

	import std.exception: enforce;
	import std.conv: text;

	alias fieldNames = RecordFormatType.tupleOfNames;
	enforce(queryResult !is null, `Expected instance of IDBQueryResult`);
	enforce(
		fieldNames.length <= queryResult.fieldCount,
		`Expected at least ` ~ fieldNames.length.text
		~ ` fields in database query result, but got ` ~ queryResult.fieldCount.text);
	IBaseDataField[] fields;
	fields.length = fieldNames.length; // preallocating
	static foreach( size_t fi, fieldName; fieldNames )
	{{
		alias fieldSpec = RecordFormatType.getFieldSpec!(fieldName);

		static if( isEnumFormat!(fieldSpec.FormatType) ) {
			alias enumFieldIndex = RecordFormatType.getEnumFormatIndex!(fieldName);
		}

		static if( fieldSpec.hasWriteableSpec )
		{
			alias CurrFieldT = MemoryDataField!(fieldSpec.FormatType);
			Optional!(fieldSpec.ValueType)[] data;
			data.length = queryResult.recordCount; // preallocating

			// Copy data from database to create memory field
			foreach( recordIndex; 0..queryResult.recordCount )
			{
				if( queryResult.isNull(fi, recordIndex) )
					continue;

				try {
					data[recordIndex] = queryResult.get(fi, recordIndex).conv!(fieldSpec.ValueType);
				} catch(ConvException ex) {
					throw new ConvException(
						`Exception during parsing value for field with name "` ~ fieldSpec.name
						~ `" at index: ` ~ recordIndex.text ~ `. Error msg:` ~ ex.to!string);
				}
			}

			static if( isEnumFormat!(fieldSpec.FormatType) ) {
				fields[fi] = new CurrFieldT(fieldName, format.enumFormats[enumFieldIndex], data);
			} else {
				fields[fi] = new CurrFieldT(fieldName, data);
			}
		}
		else
		{
			alias CurrFieldT = DatabaseField!(fieldSpec.FormatType);
			static if( isEnumFormat!(fieldSpec.FormatType) ) {
				fields[fi] = new CurrFieldT(queryResult, fi, fieldName, format.enumFormats[enumFieldIndex]);
			} else {
				fields[fi] = new CurrFieldT(queryResult, fi, fieldName);
			}
		}
	}}
	return fields;
}


unittest
{
	import webtank.datctrl.iface.record_set;
	import webtank.datctrl.record_set;
	import webtank.datctrl.typed_record_set;

	auto recFormat = RecordFormat!(
		PrimaryKey!(size_t, "num"),
		string, "name"
	)();
	IDBQueryResult queryResult;
	IBaseDataField[] dataFields = makeDataFields(queryResult, recFormat);
	auto baseRS = new RecordSet(dataFields);
	auto rs = TypedRecordSet!(typeof(recFormat), IBaseRecordSet)(baseRS);
}