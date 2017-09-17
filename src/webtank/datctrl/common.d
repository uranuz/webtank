module webtank.datctrl.common;

mixin template GetStdJSONFormatImpl()
{
	import std.json: JSONValue;
	JSONValue getStdJSONFormat()
	{
		JSONValue jValues;
		jValues["kfi"] = _keyFieldIndex; // Номер ключевого поля
		jValues["t"] = "recordset"; // Тип данных - набор записей

		//Образуем JSON-массив форматов полей
		JSONValue[] jFieldFormats;
		jFieldFormats.length = _dataFields.length;

		foreach( i, field; _dataFields ) {
			jFieldFormats[i] = field.getStdJSONFormat();
		}
		jValues["f"] = jFieldFormats;

		return jValues;
	}
}

mixin template GetStdJSONDataImpl()
{
	import std.json: JSONValue;
	JSONValue getStdJSONData(size_t index)
	{
		JSONValue[] recJSON;
		recJSON.length = _dataFields.length;
		foreach( i, dataField; _dataFields ) {
			recJSON[i] = dataField.getStdJSONValue(index);
		}
		return JSONValue(recJSON);
	}
}

mixin template GetStdJSONFieldFormatImpl()
{
	import std.json: JSONValue;
	/// Сериализации формата поля в std.json
	JSONValue getStdJSONFormat()
	{
		import std.traits: isIntegral;
		JSONValue[string] jArray;

		jArray["n"] = _name; // Вывод имени поля
		jArray["t"] = getFieldTypeString!ValueType; // Вывод типа поля
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
}

mixin template GetStdJSONFieldValueImpl()
{
	import std.json: JSONValue;
	JSONValue getStdJSONValue(size_t index)
	{
		import webtank.common.std_json: toStdJSON;
		if( !isNull(index) ) {
			return get(index).toStdJSON();
		}
		return JSONValue(null);
	}
}

string getFieldTypeString(T)()
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