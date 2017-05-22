module webtank.db.database_field;

import std.json, std.conv, std.traits, std.datetime;

import webtank.datctrl.data_field, webtank.db.database, webtank.datctrl.record_format, webtank.datctrl.enum_format;

import webtank.common.conv;

/++
$(LOCALE_EN_US
	Function converts values from different real D types to another
	real D types but coresponding to semantical field types set
	by template argument $(D_PARAM FieldT)
)

$(LOCALE_RU_RU
	Преобразование из различных настоящих типов в другой реальный
	тип, который соотвествует семантическому типу поля,
	указанному в параметре шаблона FieldT
)
+/
auto fldConv(ValueType)( string value )
{	
	static if( is( ValueType == enum )  )
	{
		return value.conv!(ValueType);
	}
	else static if( is( ValueType == bool ) )
	{
		import std.string;
		foreach(logVal; _logicTrueValues) 
			if ( logVal == toLower( strip( value ) ) ) 
				return true;
		
		foreach(logVal; _logicFalseValues) 
			if ( logVal == toLower( strip( value ) ) ) 
				return false;
				
		//TODO: Посмотреть, что делать с типами исключений в этом модуле
		throw new Exception( `Value "` ~ value.to!string ~ `" cannot be interpreted as boolean!!!` );
	}
	else static if( is( ValueType == std.datetime.Date ) )
	{
		return std.datetime.Date.fromISOExtString(value);
	}
	else
	{	
		return conv!(ValueType)( value );
	}
}

///Класс ключевого поля
class DatabaseField(FormatT) : IDataField!( FormatT )
{
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType);
	//pragma(msg, ValueType);

protected: ///ВНУТРЕННИЕ ПОЛЯ КЛАССА
	IDBQueryResult _queryResult;
	immutable(size_t) _fieldIndex;
	immutable(string) _name;
	immutable(bool) _isNullable;
	
	static if( isEnumFormat!(FormatType) )
	{	FormatType _enumFormat;
	}

public:
		
	static if( isEnumFormat!(FormatType) )
	{	
		this( IDBQueryResult queryResult, 
			size_t fieldIndex,
			string fieldName, bool isNullable,
			FormatType enumFormat
		)
		{	_queryResult = queryResult;
			_fieldIndex = fieldIndex;
			_name = fieldName;
			_isNullable = isNullable;
			_enumFormat = enumFormat;
		}
		
		///Возвращает формат значения перечислимого типа
		FormatType enumFormat()
		{	return _enumFormat;
		}
	}
	else
	{
		this( IDBQueryResult queryResult, size_t fieldIndex, string fieldName, bool isNullable )
		{	_queryResult = queryResult;
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
		size_t length() @property
		{	return _queryResult.recordCount; }
		
		string name() @property
		{	return _name; }
		
		///Возвращает true, если поле может быть пустым и false - иначе
		bool isNullable() @property
		{	return _isNullable; }
		
		///Возвращает false, поскольку поле не записываемое
		bool isWriteable() @property
		{	return false; //Поле только для чтения из БД
		}
		
		///Возвращает true, если поле пустое или false - иначе
		bool isNull(size_t index)
		{	import std.conv;
			assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) 
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			return 
				( _isNullable ? 
				_queryResult.isNull( _fieldIndex, index ) 
				: false );
		}

		///Метод сериализации формата поля в std.json
		JSONValue getStdJSONFormat()
		{
			import std.traits: isIntegral;
			JSONValue[string] jArray;

			jArray["n"] = _name; // Вывод имени поля
			jArray["t"] = _getTypeStr!(ValueType); // Вывод типа поля
			jArray["dt"] = ValueType.stringof; // D-шный тип поля

			static if( isIntegral!(ValueType) ) {
				jArray["sz"] = ValueType.sizeof; // Размер чисел в байтах
			}

			static if( isEnumFormat!(FormatType) ) {
				//Сериализуем формат для перечислимого типа (выбираем все поля формата)
				jArray["enum"] = _enumFormat.toStdJSON();
			}
			
			return JSONValue(jArray);
		}
		
		///Получение данных из поля по порядковому номеру index
		ValueType get(size_t index)
		{	assert( index <=  _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) 
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			return fldConv!( ValueType )( _queryResult.get(_fieldIndex, index) );
		}
		
		///Получение данных из поля по порядковому номеру index
		///Возвращает defaultValue, если значение поля пустое
		ValueType get(size_t index, ValueType defaultValue)
		{	
			assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) 
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			return ( isNull(index) ? defaultValue : fldConv!( ValueType )( _queryResult.get(_fieldIndex, index) ) );
		}
		
		///Получает строковое представление данных
		string getStr(size_t index)
		{
			assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) 
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			
			static if( isEnumFormat!(FormatType) )
			{
				
				if( isNull(index) )
				{	
					return null;
				}
				else
				{
					return _enumFormat.getStr( fldConv!( ValueType )( _queryResult.get(_fieldIndex, index) ) );
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
			assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) 
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
				
			if( isNull(index) )
			{
				return defaultValue;
			}
			else
			{
				static if( isEnumFormat!(FormatType) )
				{
					return _enumFormat.getStr( fldConv!( ValueType )( _queryResult.get(_fieldIndex, index) ) );
				}
				else
				{	
					//TODO: добавить проверку на соответствие значения базовому типу поля
					return _queryResult.get(_fieldIndex, index).to!string;
				}
			
			}
		}
	} //override

	private string _getTypeStr(T)()
	{
		import std.traits;
		import std.datetime: SysTime, DateTime, Date;

		static if( is(T: void) ) {
			return "void";
		} else static if( is(T: bool) ) {
			return "bool";
		} else static if( isIntegral!(T) ) {
			return "int";
		} else static if( isSomeString!(T) ) {
			return "str";
		} else static if( isArray!(T) ) {
			return "array";
		} else static if( isAssociativeArray!(T) ) {
			return "assocArray";
		} else static if( is( T: SysTime ) || is( T: DateTime) ) {
			return "dateTime";
		} else static if( is( T: Date ) ) {
			return "date";
		} else {
			return "<unknown>";
		}
	}
}

