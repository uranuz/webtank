module webtank.datctrl.enum_format;

import std.traits, std.range;
import webtank.common.conv;

import webtank.datctrl.iface.record_set: IBaseRecordSet;
import webtank.datctrl.iface.record: IBaseRecord;
import webtank.datctrl.iface.data_field: IBaseDataField;
import webtank.datctrl.cursor_record: CursorRecord;

/++
$(LANG_EN Struct represents format for enumerated type of field)
$(LANG_RU Структура представляет формат для перечислимого типа поля)
+/
class EnumFormat(T, bool withNames): IBaseRecordSet
{
	import std.typecons: Tuple;
	import std.algorithm: canFind;

	alias ValueType = T;
	alias hasNames = withNames;

	import webtank.datctrl.cursor_record: CursorRecord;
	import webtank.datctrl.iface.record_set: IRecordSetRange;
	enum bool isWriteableFlag = false;
	alias RecordSetIface = IBaseRecordSet;
	alias DataFieldIface = IBaseDataField;
	alias RangeIface = InputRange!IBaseRecord;
	alias RecordIface = IBaseRecord;
	alias RecordType = CursorRecord;

protected:
	size_t[string] _recordIndexes;

	RecordType[] _cursors;
	size_t[RecordType] _cursorIndexes;

public:
	void _reindexRecords()
	{
		import std.conv: to;
		import std.exception: enforce;
		_recordIndexes.clear();
		_cursorIndexes.clear();
		foreach( size_t i, item; _values )
		{
			string keyValue = ((it) {
				import std.conv: to;
				static if( hasNames )
					return it[0];
				else
					return it;
			})(item).to!string;
			enforce(keyValue !in _recordIndexes, `Enum key "` ~ keyValue ~ `" is not unique!`);
			_recordIndexes[keyValue] = i;
		}

		// Индексируем курсоры
		foreach( i, curs; _cursors ) {
			_cursorIndexes[curs] = i;
		}
	}

	void _initCursors()
	{
		// Создаем курсоры. При этом при каждом получении записи будет физически один и тот же курсор
		foreach( i; 0..this.length ) {
			_cursors ~= new RecordType(this);
		}
	}

	override {
		IBaseDataField getField(string fieldName) {
			throw new Exception(`getField for enum format is not implemented yet`);
		}

		IBaseRecord opIndex(size_t recordIndex) {
			return getRecordAt(recordIndex);
		}

		IBaseRecord getRecordAt(size_t recordIndex)
		{
			import std.exception: enforce;
			enforce(recordIndex < _cursors.length, `No item with specified index in enum format`);

			return _cursors[recordIndex];
		}

		string getStr(string fieldName, size_t recordIndex)
		{
			import std.exception: enforce;
			enforce(recordIndex < _values.length, `No value with specified index in enum format`);

			static if( hasNames )
			{
				import std.algorithm: canFind;
				import std.conv: to;
				enforce(["name", "value"].canFind(fieldName), `Expected "name" or "value" field name`);
				auto item = _values[recordIndex];
				return fieldName == "name"? item[1]: item[0].to!string;
			} else {
				enforce(fieldName == "value", `Expected "value" field name`);
				return _values[recordIndex].to!string;
			}
		}

		string getStr(string fieldName, size_t recordIndex, string defaultValue)
		{
			string res = getStr(fieldName, recordIndex);
			return res.length > 0? res: defaultValue;
		}

		size_t keyFieldIndex() @property {
			return 0;
		}

		bool isNull(string fieldName, size_t recordIndex) {
			return false;
		}

		bool isNullable(string fieldName) {
			return false;
		}

		bool isWriteable(string fieldName) {
			return false;
		}

		size_t length() @property inout {
			return _values.length;
		}

		size_t fieldCount() @property inout
		{
			static if( hasNames ) {
				return 2;
			} else {
				return 1;
			}
		}

		import std.json: JSONValue;

		JSONValue getStdJSONData(size_t index) inout
		{
			import std.exception: enforce;
			import webtank.common.std_json.to: toStdJSON;
			enforce(index < _values.length, `Cannot get value with specified index in enum format`);

			static if( hasNames ) {
				return JSONValue([_values[index][0].toStdJSON(), JSONValue(_values[index][1])]);
			} else {
				return JSONValue([_values[index].toStdJSON()]);
			}
		}

		JSONValue getStdJSONFormat() inout
		{
			//Массив элементов перечислимого типа
			JSONValue[] jEnumItems;

			jEnumItems.length = _values.length;
			foreach( i; 0.._values.length ) {
				jEnumItems[i] = getStdJSONData(i);
			}
			return JSONValue(jEnumItems);
		}

		/++
		$(LANG_EN Serializes enumerated field format into std.json)
		$(LANG_RU Сериализует формат перечислимого типа в std.json)
		+/
		JSONValue toStdJSON() inout
		{
			import webtank.common.std_json: toStdJSON;
			import webtank.datctrl.common: getFieldTypeString;
			import webtank.datctrl.consts: SrlField, SrlEntityType;

			JSONValue res;
			res[SrlField.enum_] = getStdJSONFormat();
			res[SrlField.type] = SrlEntityType.enum_;
			res[SrlField.valueType] = getFieldTypeString!ValueType;
			res[SrlField.dLangType] = ValueType.stringof;

			return res;
		}

		IRecordSetRange opSlice() {
			return new Range(this);
		}

		IBaseRecordSet opSlice(size_t begin, size_t end)
		{
			import webtank.datctrl.record_set_slice: RecordSetSlice;
			return new RecordSetSlice(this, begin, end);
		}

		size_t getIndexByStringKey(string recordKey)
		{
			import std.exception: enforce;
			enforce(recordKey in _recordIndexes, `Cannot find enum item with specified key!`);
			return _recordIndexes[recordKey];
		}

		size_t getIndexByCursor(IBaseRecord cursor)
		{
			import std.exception: enforce;
			RecordType typedCursor = cast(RecordType) cursor;
			enforce(typedCursor, `Enum item type mismatch`);
			enforce(typedCursor in _cursorIndexes, `Cannot get index in enum format for specified item`);
			return _cursorIndexes[typedCursor];
		}
	}

	static if( hasNames )
	{
		//Массив пар "значение: название" для перечислимого типа
		private Tuple!(ValueType, string)[] _values;

		this( Tuple!(ValueType, string)[] pairs )
		{
			_values = pairs;
		}

		string getName(ValueType value) const
		{
			foreach( ref pair; _values )
			{
				if( pair[0] == value )
					return pair[1];
			}
			throw new Exception("Attempt to get name for value *" ~ value.conv!string ~ "* that doesn't exist in EnumFormat object!!" ~ _values.conv!string);
		}

		ValueType getValue(string name) const
		{
			foreach( ref pair; _values )
			{
				if( pair[1] == name )
					return pair[0];
			}
			throw new Exception("Attempt to get value for name that doesn't exist in EnumFormat object!!");
		}

		bool hasName(string name) const {
			return _values.canFind!( (a, b) => a[1] == b )(name);
		}

		bool hasValue(ValueType value) const {
			return _values.canFind!( (a, b) => a[0] == b )(value);
		}

		///Возвращает набор имен для перечислимого типа
		string[] names() @property const
		{
			string[] result;
			result.length = _values.length;

			foreach( i, ref pair; _values )
				result[i] = pair[1];

			return result;
		}

		///Возвращает набор значений перечислимого типа
		ValueType[] values() @property const
		{
			ValueType[] result;
			result.length = _values.length;

			foreach( i, ref pair; _values )
				result[i] = pair[0];

			return result;
		}

		///Оператор для обхода значений перечислимого типа через foreach
		///Первый параметр - имя (строка), второй - значение
		int opApply(int delegate(string name, ValueType value) dg) const
		{
			foreach( ref pair; _values )
			{
				auto result = dg(pair[1], pair[0]);
				if(result)
					return result;
			}
			return 0;
		}

		///Оператор для обхода значений перечислимого типа через foreach
		///в случае одного параметра (значения)
		int opApply(int delegate(ValueType value) dg)
		{
			foreach( ref pair; _values )
			{
				auto result = dg(pair[0]);
				if(result)
					return result;
			}
			return 0;
		}
	}
	else
	{
		//Массив значений перечислимого типа
		private ValueType[] _values;

		this( ValueType[] values )
		{
			_values = values;
		}

		bool hasValue(ValueType value) const {
			return _values.canFind(name);
		}

		///Возвращает набор значений перечислимого типа
		ValueType[] values() @property const
		{
			return _values.dup;
		}

		///Оператор для обхода значений перечислимого типа через foreach
		///в случае одного параметра (значения)
		int opApply(int delegate(ValueType value) dg)
		{
			foreach( ref value; _values )
			{
				auto result = dg(value);
				if(result)
					return result;
			}
			return 0;
		}
	}

	string getStr(ValueType value) const
	{
		static if( hasNames )
		{
			return getName( value );
		}
		else static if( isSomeString!(ValueType) )
		{
			if( !_values.canFind(value) )
				throw new Exception("Value is not present in enum format!");
			return value.conv!string;
		}
		else static if( is( ValueType == enum ) )
		{
			alias BaseType = OriginalType!(ValueType);
			static if( isSomeString!(BaseType) )
			{
				if( !_values.canFind(value) )
					throw new Exception("Value is not present in enum format!");
				return value.conv!string;
			}
			else
			{
				//Вывод идентификатора значения перечислимого типа из кода на D
				return value.stringof;
			}
		}
		else
		{
			if( !_values.canFind(value) )
				throw new Exception("Value is not present in enum format!");
			return value.conv!string;
		}
	}

	string opIndex(ValueType value) const
	{
		return getStr(value);
	}

	///Оператор in для проверки наличия ключа в наборе значений перечислимого типа
	bool opBinaryRight(string op)(ValueType value) inout
		if( op == "in" )
	{	return hasValue(value); }

	import webtank.datctrl.record_set_range: RecordSetRangeImpl;
	mixin RecordSetRangeImpl;
}

import std.range: ElementType;
import std.typecons: isTuple;

enum isEnumFormat(E) = isInstanceOf!(EnumFormat, E);

auto enumFormat(Pair)(Pair[] pairs)
	if( isTuple!(Pair) && Pair.length == 2 )
{
	return new EnumFormat!( typeof(pairs[0][0]), true )(pairs);
}

auto enumFormat(T)(T[] values)
	if( !isTuple!(T) )
{
	return new EnumFormat!(T, false)(values);
}