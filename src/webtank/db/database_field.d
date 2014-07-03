module webtank.db.database_field;

import std.json, std.conv;

import webtank.datctrl.data_field, webtank.db.database, webtank.datctrl.record_format;

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
auto fldConv(FieldType FieldT, S)( S value )
{	
	import std.traits;
// 	// целые числа --> DataFieldValueType!(FieldT)
// 	static if( isIntegral!(S) )
// 	{	with( FieldType ) {
// 		//Стандартное преобразование
// 		static if( FieldT == Int || FieldT == Str || FieldT == IntKey )
// 		{	return value.to!( DataFieldValueType!FieldT ); }
// 		else static if( FieldT == Bool ) //Для уверенности
// 		{	return ( value == 0 ) ? false : true ; }
// 		else
// 			static assert( 0, _notImplementedErrorMsg ~ typeof(value).stringof ~ " --> " ~ FieldT.to!string );
// 		}  //with( FieldType )
// 		assert(0);
// 	}
	
	// строки --> DataFieldValueType!(FieldT)
	//else 
	static if( isSomeString!(S) )
	{	with( FieldType ) {
		//Стандартное преобразование
		static if( FieldT == Int || FieldT == Str || FieldT == IntKey || FieldT == Enum )
		{	return value.to!( DataFieldValueType!FieldT ); }
		else static if( FieldT == Bool )
		{	import std.string;
			foreach(logVal; _logicTrueValues) 
				if ( logVal == toLower( strip( value ) ) ) 
					return true;
			
			foreach(logVal; _logicFalseValues) 
				if ( logVal == toLower( strip( value ) ) ) 
					return false;
			
			//TODO: Посмотреть, что делать с типами исключений в этом модуле
			throw new Exception( `Value "` ~ value.to!string ~ `" cannot be interpreted as boolean!!!` );
		}
		else static if( FieldT == Date )
		{	return std.datetime.Date.fromISOExtString(value); }
		else
			static assert( 0, _notImplementedErrorMsg ~ typeof(value).stringof ~ " --> " ~ FieldT.to!string );
		}  //with( FieldType )
		assert(0);
	}
	
	// bool --> DataFieldValueType!(FieldT)
// 	else static if( is( S : bool ) )
// 	{	with( FieldType ) {
// 		static if( FieldT == Int || FieldT == IntKey || FieldT == Enum )
// 		{	return ( value ) ? 1 : 0; }
// 		else static if( FieldT == Str )
// 		{	return ( value ) ? "да" : "нет"; }
// 		else static if( FieldT == Bool )
// 		{	return value; }
// 		else
// 			static assert( 0, _notImplementedErrorMsg ~ typeof(value).stringof ~ " --> " ~ FieldT.to!string );
// 		}  //with( FieldType )
// 		assert(0);
// 	}

}

///Класс ключевого поля
class DatabaseField(FormatT) : IDataField!( FormatT )
{
	alias FormatType = FormatT;
	alias ValueType = DataFieldValueType!(FormatType) T;

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
			_name = _fieldName;
			_isNullable = isNullable;
			_enumFormat = enumFormat.mutCopy();
		}
		
		///Возвращает формат значения перечислимого типа
		FormatType enumFormat()
		{	return _enumFormat;
		}
	}

	this( IDBQueryResult queryResult, size_t fieldIndex, string fieldName, bool isNullable )
	{	_queryResult = queryResult;
		_fieldIndex = fieldIndex;
		_name = _fieldName;
		_isNullable = isNullable;
	}

	override { //Переопределяем интерфейсные методы
		///Возвращает тип поля
		//FieldType type()
		//{	return FieldT; }
		
		///Возвращает количество записей для поля
		size_t length()
		{	return _queryResult.recordCount; }
		
		string name() @property
-		{	return _name; }
		
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
			return ( _isNullable ? _queryResult.isNull( _fieldIndex, index ) : false );
		}
		
		///Метод сериализации формата поля в std.json
		JSONValue getStdJSONFormat()
		{	
			JSONValue[string] jArray;
			
			jArray["n"] = _name; //Вывод имени поля
			jArray["t"] = FieldT.to!string; //Вывод типа поля
			
			static if( FieldT == FieldType.Enum )
			{	//Сериализуем формат для перечислимого типа (выбираем все поля формата)
				foreach( string key, val; _enumFormat.getStdJSON() )
					jArray[key] = val;
			}
			
			return JSONValue(jArray);
		}
		
		///Получение данных из поля по порядковому номеру index
		T get(size_t index)
		{	
			assert( index <=  _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) 
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			return fldConv!( FieldT )( _queryResult.get(_fieldIndex, index) );
		}
		
		///Получение данных из поля по порядковому номеру index
		///Возвращает defaultValue, если значение поля пустое
		T get(size_t index, T defaultValue)
		{	
			assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) 
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			return ( isNull(index) ? defaultValue : fldConv!( FieldT )( _queryResult.get(_fieldIndex, index) ) );
		}
		
		///Получает строковое представление данных
		string getStr(size_t index)
		{
		
		}
		
		///Получает строковое представление данных
		string getStr(size_t index, string defaultValue)
		{	
			assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) 
				~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			
			static if( isEnumFormat!(FormatType) )
			{	if( isNull(index) )
				{	return _enumFormat.nullString;
					
				}
// 				else
// 				{	_enumFormat.
// 					
// 				}
				
				
			}
			else
			{	
				
			}
			
			return ( isNull(index) ? defaultValue : _queryResult.get(_fieldIndex, index) );
		}
	} //override


}

