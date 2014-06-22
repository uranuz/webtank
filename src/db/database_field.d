module webtank.db.database_field;

import std.json, std.conv;

import webtank.datctrl.data_field, webtank.db.database, webtank.datctrl.record_format;



///Класс ключевого поля
class DatabaseField(FieldType FieldT) : IDataField!( FieldT )
{
protected: ///ВНУТРЕННИЕ ПОЛЯ КЛАССА
	alias DataFieldValueType!(FieldT) T;

	IDBQueryResult _queryResult;
	immutable(size_t) _fieldIndex;
	immutable(string) _name;

	//Поля от формата поля
	static if( isKeyFieldType!(FieldT))
	{	size_t[size_t] _indexes;
		size_t[] _keys;   //Массив ключей
	}
	else
	{	bool _isNullable = true;
	}
	
	static if( FieldT == FieldType.Enum )
	{	EnumFormat _enumFormat;
	}

public:
		
	static if( FieldT == FieldType.Enum )
	{	this( IDBQueryResult queryResult, 
			size_t fieldIndex, 
			string fieldName, 
			const(EnumFormat) enumFormat
		)
		{	_queryResult = queryResult;
			_fieldIndex = fieldIndex;
			_name = fieldName;
			_enumFormat = enumFormat.mutCopy();
		}
		
		///Возвращает формат значения перечислимого типа
		EnumFormat enumFormat()
		{	return _enumFormat;
		}
	}

	this( IDBQueryResult queryResult, 
		size_t fieldIndex, 
		string fieldName 
	)
	{	_queryResult = queryResult;
		_fieldIndex = fieldIndex;
		_name = fieldName;
		
		static if( isKeyFieldType!(FieldT) )
			_readKeys();
	}

	override { //Переопределяем интерфейсные методы
		///Возвращает тип поля
		FieldType type()
		{	return FieldT; }
		
		///Возвращает количество записей для поля
		size_t length()
		{	static if( isKeyFieldType!(FieldT) )
				return _indexes.length;
			else
				return _queryResult.recordCount;
		}
		
		string name() @property
		{	return _name; }
		
		///Возвращает true, если поле может быть пустым и false - иначе
		bool isNullable() @property
		{	static if( isKeyFieldType!(FieldT) )
				return false;
			else
				return _isNullable; 
		}
		
		///Возвращает false, поскольку поле не записываемое
		bool isWriteable() @property
		{	return false; //Поле только для чтения из БД
		}
		
		///Возвращает true, если поле пустое или false - иначе
		bool isNull(size_t index)
		{	static if( isKeyFieldType!(FieldT) )
				return false;
			else
			{	import std.conv;
				assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) ~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
				return ( _isNullable ? _queryResult.isNull( _fieldIndex, index ) : false );
			}
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
		{	static if( isKeyFieldType!(FieldT) )
			{	assert( index <= _indexes.length, "Field index '" ~ std.conv.to!string(index) ~ "' is out of bounds, because _indexes.length is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
				assert( !isNull(index), "Key field value must not be null!!!" );
			}
			else
				assert( index <=  _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) ~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			return fldConv!( FieldT )( _queryResult.get(_fieldIndex, index) );
		}
		
		///Получение данных из поля по порядковому номеру index
		///Возвращает defaultValue, если значение поля пустое
		T get(size_t index, T defaultValue)
		{	static if( isKeyFieldType!(FieldT) )
				assert( index <= _indexes.length, "Field index '" ~ std.conv.to!string(index) ~ "' is out of bounds, because _indexes.length is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			else
				assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) ~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			return ( isNull(index) ? defaultValue : fldConv!( FieldT )( _queryResult.get(_fieldIndex, index) ) );
		}
		
		///Получает "сырое" строковое представление данных
		string getStr(size_t index, string defaultValue = null)
		{	static if( isKeyFieldType!(FieldT) )
			{	assert( index <= _indexes.length, "Field index '" ~ std.conv.to!string(index) ~ "' is out of bounds, because _indexes.length is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
				assert( isNull(index), "Key field value must not be null!!!" );
			}
			else
				assert( index <= _queryResult.recordCount, "Field index '" ~ std.conv.to!string(index) ~ "' is out of bounds, because record count is '" ~ std.conv.to!string(_queryResult.recordCount) ~ "'!!!" );
			
			static if( FieldT == FieldType.Enum )
			{	if( isNull(index) )
				{	return _enumFormat.defaultName;
					
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

		static if( isKeyFieldType!(FieldT) )
		{	///Возвращает порядковый номер ячейки со значением ключа key
			size_t getIndex(size_t key)
			{	if( key in _indexes )
					return _indexes[key];
				else
					throw new Exception(`Ключ ` ~ key.to!string ~ ` не найден в поле данных!!!`);
				//else
					//TODO: Выдавать ошибку
			}
			
			///Возвращает значение ключа по порядковому номеру ячейки index
			size_t getKey(size_t index)
			{	if( index < _keys.length )
					return _keys[index];
				else
					throw new Exception(`Индекс ` ~ index.to!string ~ ` не найден в поле данных!!!`);
			}
		}
		
			
	} //override
	
// 	bool keyExists(size_t key)
// 	{	if( key in _indexes ) return true;
// 		return false;
// 	}
	
	
	
protected:

	static if( isKeyFieldType!(FieldT) )
	{
		void _readKeys()
		{	auto recordCount = _queryResult.recordCount;
			for( size_t i = 0; i < recordCount; i++ )
			{	auto key = std.conv.to!(size_t)( _queryResult.get(_fieldIndex, i) );
				_keys ~= key;
				_indexes[key] = i;
			}
		}
	}
	
	// 	void set( T value, size_t key )
	// 	{	if( !keyExists(key) ) assert(0);
	// 		_nullFlags[ _getIndex(key) ] = false;
	// 		//Значение должно копироваться (для текста)
	// 		_values[ _getIndex(key) ] = value;
	// 	}

}

