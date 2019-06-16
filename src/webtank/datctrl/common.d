module webtank.datctrl.common;

mixin template GetStdJSONFormatImpl()
{
	import std.json: JSONValue;
	JSONValue getStdJSONFormat() inout
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
	JSONValue getStdJSONData(size_t index) inout
	{
		JSONValue[] recJSON;
		recJSON.length = _dataFields.length;
		foreach( i, dataField; _dataFields ) {
			recJSON[i] = dataField.getStdJSONValue(index);
		}
		return JSONValue(recJSON);
	}
}

mixin template RecordSetToStdJSONImpl()
{
	import std.json: JSONValue;
	JSONValue toStdJSON() inout
	{
		auto jValues = this.getStdJSONFormat();

		JSONValue[] jData;
		jData.length = this.length;

		foreach( i; 0..this.length ) {
			jData[i] = this.getStdJSONData(i);
		}

		jValues["d"] = jData;
		jValues["t"] = "recordset";

		return jValues;
	}
}

mixin template GetStdJSONFieldFormatImpl()
{

	import std.json: JSONValue;
	/// Сериализации формата поля в std.json
	JSONValue getStdJSONFormat() inout
	{
		JSONValue res;

		static if( isEnumFormat!(FormatType) ) {
			res = _enumFormat.toStdJSON();
		} else {
			import std.traits: isIntegral, isFloatingPoint, isArray, isAssociativeArray, isSomeString;
			res["t"] = getFieldTypeString!ValueType; // Вывод типа поля
			res["dt"] = ValueType.stringof; // D-шный тип поля

			static if( isIntegral!(ValueType) || isFloatingPoint!(ValueType) ) {
				res["sz"] = ValueType.sizeof; // Размер чисел в байтах
			}

			static if( isArray!ValueType && !isSomeString!ValueType ) {
				import std.range: ElementType;
				res["vt"] = getFieldTypeString!(ElementType!ValueType);
			} else static if( isAssociativeArray!(ValueType) ) {
				import std.traits: TKeyType = KeyType, TValueType = ValueType;
				res["vt"] = getFieldTypeString!(TValueType!ValueType);
				res["kt"] = getFieldTypeString!(TKeyType!ValueType);
			}
		}
		res["n"] = _name; // Вывод имени поля

		return res;
	}
}

mixin template GetStdJSONFieldValueImpl()
{
	import std.json: JSONValue;
	JSONValue getStdJSONValue(size_t index) inout
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
	} else static if( isFloatingPoint!(T) ) {
		return "float";
	} else static if( isSomeString!(T) ) {
		return "str";
	} else static if( isArray!(T) ) {
		return "array";
	} else static if( isAssociativeArray!(T) ) {
		return "assocArray";
	} else static if( is( Unqual!T == SysTime ) || is( Unqual!T == DateTime) ) {
		return "dateTime";
	} else static if( is( Unqual!T == Date ) ) {
		return "date";
	} else {
		return "<unknown>";
	}
}