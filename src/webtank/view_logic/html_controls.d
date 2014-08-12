module webtank.view_logic.html_controls;

import std.conv, std.datetime, std.array, std.stdio, std.typecons;

import webtank.net.utils, webtank.datctrl.record_format, webtank.datctrl.enum_format;

class HTMLControl
{
	string name;  ///Имя поля ввода
	string[] classes; ///Набор HTML-классов присвоенных списку
	string id;  ///HTML-идентификатор поля ввода
}

///Простенький класс для генерации HTML-разметки для выпадающего списка элементов
class ListBox(ValueSetT): HTMLControl
{	
	alias ValueSetType = ValueSetT;
	
	static if( isEnumFormat!(ValueSetType) )
	{
		alias ValueType = ValueSetType.ValueType;
		enum bool hasNames = ValueSetType.hasNames;
	}
	else static if( isArray!(ValueSetType) )
	{
		import std.range;
		static if( isTuple!( ElementType!(ValueSetType) ) )
		{
			static assert( ElementType!(ValueSetType).length == 2, `Tuple must contain 2 elements!` );
			static assert( is( ElementType!(ValueSetType)[1] == string ), `Name for value in ListBox must be of string type!!!` );
			alias ValueType = typeof(ElementType!(ValueSetType)[0]);
			enum bool hasNames = true;
		}
		else
		{
			alias ValueType = ElementType!(ValueSetType);
			enum bool hasNames = false;
		}
	}
	else
		static assert( 0, `Generating drop down list from value set "` ~ ValueSetType.stringof ~ `" is not supported!!!` );
	
	this( ValueSetT set ) const
	{
		valueSet = set;
	}
	
	this( ValueSetT set )
	{
		valueSet = set;
	}
	
	private string _renderItem( ValueType value, string name )
	{
		import webtank.common.conv;
		return `<option value="` ~ value.conv!string ~ `"`
				~ ( _selectedValues.canFind(value) ? ` selected` : `` ) ~ `>`
				~ HTMLEscapeText(name) ~ `</option>`;
	}
	
	///Метод генерирует разметку по заданным параметрам
	string print()
	{	
		import webtank.common.conv;
		
		string[string] selectAttrs;
		
		if( name.length > 0 )
			selectAttrs["name"] = name;
			
		if( id.length > 0 )
			selectAttrs["id"] = id;
			
		if( classes.length > 0 )
			selectAttrs["class"] = HTMLEscapeValue( join(classes, ` `) );
			
		if( isMultiSelect )
			selectAttrs["multiple"] = null;
			
		string output = `<select` ~ printHTMLAttributes(selectAttrs) ~ `>`;
		
		if( isNullable )
			output ~= `<option` ~ ( isNull ? ` selected` : `` ) ~ `>`
			~ HTMLEscapeText(nullName) ~ `</option>`;
		
		static if( isEnumFormat!(ValueSetType) )
		{
			foreach( name, value; valueSet )
			{	output ~= _renderItem(value, name);
			}
		
		}
		else static if( isArray!(ValueSetType) )
		{
			static if( hasNames )
			{
				foreach( name, value; valueSet )
				{	output ~= _renderItem(value, name);
				}
			}
			else
			{
				foreach( value; valueSet )
				{	output ~= _renderItem(value, value.conv!string);
				}
			}
		}
		
		output ~= `</select>`;
		
		return output;
	}
	
	ValueSetT valueSet; ///Значения выпадающего списка (перечислимый тип)
	string nullName;
	
	ValueType selectedValue() @property  ///Текущее значение списка
	{	return _selectedValues[0]; }
	
	///Свойство: текущее значение списка
	void selectedValue(ValueType value) @property
	{	_selectedValues = [ value ];
	}
	
	void selectedValues(ValueType[] values) @property
	{
		_selectedValues = values;
	}
	
	ValueType[] selectedValues() @property
	{
		return _selectedValues.dup;
	}
	
	bool isNull() @property
	{	return _selectedValues.length == 0; }
	
	bool isNullable() @property
	{
		return _isNullable;
	}
	
	bool isMultiSelect() @property
	{
		return _selectedValues.length > 1;
	}
	
	void setNullable(bool value)
	{
		_isNullable = value;
	}
	
	void nullify()
	{	_selectedValues = null;
	}

protected:
	bool _isNullable = true;
	ValueType[] _selectedValues;
}

auto listBox(T)(T valueSet)
{
	return new ListBox!(T)(valueSet);
}

static immutable months = 
	[	"январь", "февраль", "март", 
		"апрель", "май", "июнь", 
		"июль", "август", "сентябрь", 
		"октябрь", "ноябрь", "декабрь"
	];

	
///Простой класс для создания HTML компонента выбора данных
///Состоит из двух текстовых полей (день, год) и выпадающего списка месяцев
class PlainDatePicker: HTMLControl
{	
	
	string print()
	{	
		string[string][string] attrBlocks = 
		[	`year`: null, `month`: null, `day`: null ];
		
		//Задаём базовые аттрибуты для окошечек календаря
		foreach( word, ref attrs; attrBlocks )
		{	if( name.length > 0 ) //Путсые аттрибуты не записываем
				attrs["name"] = word ~ `_of_` ~ name;
				
			if( id.length > 0 )
				attrs["id"] = word ~ `_of_` ~ id;
				
			if( classes.length > 0 )
				attrs["class"] = HTMLEscapeValue( join(classes, ` `) );
		}
		
		//Задаём доп. аттрибуты и значения для дня и месяца
		attrBlocks[`year`]["type"] = `text`;
		attrBlocks[`day`]["type"] = `text`;
		
		//Размеры окошечек для дня и года
		attrBlocks[`year`]["size"] = `4`;
		attrBlocks[`day`]["size"] = `2`;
		
		attrBlocks[`year`]["value"] = _year == 0 ? null : _year.to!string;
		attrBlocks[`day`]["value"] = _day == 0 ? null : _day.to!string;
		
		attrBlocks[`year`]["placeholder"] = nullYearName;
		attrBlocks[`day`]["placeholder"] = nullDayName;
		
		//Собираем строки окошечек для вывода
		string yearInp = `<input` ~ printHTMLAttributes(attrBlocks[`year`]) ~ `>`;
		string dayInp = `<input` ~ printHTMLAttributes(attrBlocks[`day`]) ~ `>`;
		
		string monthInp = `<select` ~ printHTMLAttributes(attrBlocks[`month`]) ~ `>`
			~ `<option` ~ ( _month == 0 ? `` : ` selected` ) ~ `>`
			~ nullMonthName ~ `</option>`;
		
		foreach( i, month; months )
		{	monthInp ~= `<option value="` ~ (i+1).to!string ~ `"`
			~ ( i+1 == date.month ? ` selected` : `` )
			~ `>` ~ month ~ `</option>`;
		}
		monthInp ~= `</select>`;
		
		return dayInp ~ ` ` ~ monthInp ~ ` ` ~ yearInp;
	}
	
	string nullDayName;
	string nullMonthName;
	string nullYearName;
	
	Date date() @property
	{	return Date(_year, _month, _day);
	}
	
	void date(Date value) @property
	{	
		_year = value.year;
		_month = value.month;
		_day = value.day;
	}
	
	void day(int day) @property
	{	_day = cast(ubyte) day; }
	
	void day(Optional!int day) @property
	{	_day = cast(ubyte) day.get(0); }
	
	void month(int month) @property
	{	_month = cast(ubyte) month; }
	
	void month(Optional!int month) @property
	{	_month = cast(ubyte) month.get(0); }
	
	void year(int year) @property
	{	_year = cast(short) year; }
	
	void year(Optional!int year) @property
	{	_year = cast(short) year.get(0); }
	
	bool isNull() @property
	{	return _year == 0 && _month == 0 && _day == 0; }
	
	void nullify()
	{	_year = 0;
		_month = 0;
		_day = 0;
	}

protected:
	short _year;
	ubyte _month;
	ubyte _day;
}

string printHTMLAttributes(string[string] values)
{	string result;
	foreach( attrName, attrValue; values )
	{	if( attrName.length > 0 )
			result ~= ` ` ~ attrName 
				~ ( attrValue.length > 0 ? `="` ~ HTMLEscapeValue(attrValue) ~ `"` : `` );
	}
	return result;
}
