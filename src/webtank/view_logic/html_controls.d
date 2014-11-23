module webtank.view_logic.html_controls;

import std.conv, std.datetime, std.array, std.stdio, std.typecons;

import webtank.net.utils, webtank.datctrl.record_format, webtank.datctrl.enum_format, webtank.common.optional;

class HTMLControl
{
	string name;  ///Имя поля ввода
	string[] classes; ///Набор HTML-классов присвоенных списку
	string id;  ///HTML-идентификатор поля ввода
}

template HTMLListControlValueSetSpec(ValueSetType)
{
	static if( isEnumFormat!(ValueSetType) )
	{
		alias ValueType = ValueSetType.ValueType;
		enum bool hasNames = ValueSetType.hasNames;
	}
	else static if( isArray!(ValueSetType) )
	{
		import std.range : ElementType;
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
}

///Простенький класс для генерации HTML-разметки для выпадающего списка элементов
class HTMLListControl(ValueSetT): HTMLControl
{	
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	this( ValueSetT set ) const
	{
		_valueSet = set;
	}
	
	this( ValueSetT set )
	{
		_valueSet = set;
	}
	
	abstract string _renderItem( ValueType value, string name, string name_attr );
	
	string _renderItems()
	{
		string output;
		static if( isEnumFormat!(ValueSetType) )
		{
			foreach( name, value; _valueSet )
				output ~= _renderItem(value, name, this.name);
		}
		else static if( isArray!(ValueSetType) )
		{
			static if( hasNames )
			{
				foreach( name, value; _valueSet )
					output ~= _renderItem(value, name, this.name);
			}
			else
			{
				foreach( value; _valueSet )
					output ~= _renderItem(value, value.conv!string, this.name);
			}
		}
		
		return output;
	}
	
	
	void selectedValue(ValueType value) @property
	{	_selectedValues = [value];
	}
	
	void selectedValue(Optional!ValueType value) @property
	{
		if( value.isNull() )
			_selectedValues = null;
		else
			_selectedValues = [value.value];
	}
	
	private static string _genMethodDecls(string[] types)
	{
		string result;
		
		foreach( type; types )
		{
			result ~= 
			`void selectedValue(Optional!` ~ type ~ ` value) @property
			{
				if( value.isNull )
					_selectedValues = null;
				else
					_selectedValues = [value.value];
			}
			`;
		}
		
		return result;
	}
	
	static if( is( ValueType == int ) )
	{
		private enum _intImplicitlyCastedTypes = [
			"bool", "byte", "ubyte", "short", "ushort", "char", "wchar"
		];
		
		mixin( _genMethodDecls(_intImplicitlyCastedTypes) );
		
		//Disable buggy conversion from uint to int
		mixin( "@disable \r\n" ~_genMethodDecls(["uint"]) );
	}
	else static if( is( ValueType == uint) )
	{
		mixin( _genMethodDecls(["dchar"]) );
	}

	bool isNull() @property
	{	return _selectedValues.length == 0;
	}
	
	bool isNullable() @property
	{	return _isNullable;
	}
	
	string nullName() @property
	{	return _nullName;
	}
	
	void nullName(string value) @property
	{	_nullName = value;
	}
	
	void setNullable(bool value)
	{	_isNullable = value;
	}
	
	void nullify()
	{	_selectedValues = null;
	}

protected:
	bool _isNullable = true;
	string _nullName;
	ValueType[] _selectedValues;
	ValueSetType _valueSet;
}

///Простенький класс для генерации HTML-разметки для выпадающего списка элементов
class ListBox(ValueSetT): HTMLListControl!(ValueSetT)
{	
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	this( ValueSetT set ) const
	{
		super(set);
	}
	
	this( ValueSetT set )
	{
		super(set);
	}
	
	override string _renderItem( ValueType value, string name, string name_attr )
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
			output ~= `<option value=""` ~ ( isNull ? ` selected` : `` ) ~ `>`
			~ HTMLEscapeText(nullName) ~ `</option>`;
		
		output ~= _renderItems() ~ `</select>`;
		
		return output;
	}
	
	void selectedValues(ValueType[] values) @property
	{	_selectedValues = values;
	}
	
	ValueType[] selectedValues() @property
	{	return _selectedValues.dup;
	}
	
	bool isMultiSelect() @property
	{	return _selectedValues.length > 1 || _isMultiSelect;
	}
	
	void isMultiSelect(bool value) @property
	{	_isMultiSelect = value;
	}

protected:
	bool _isMultiSelect = false;
	ValueType[] _selectedValues;
}

auto listBox(T)(T valueSet)
{
	return new ListBox!(T)(valueSet);
}

class CheckBoxList(ValueSetT): HTMLListControl!(ValueSetT)
{
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	this( ValueSetT set ) const
	{
		super(set);
	}
	
	this( ValueSetT set )
	{
		super(set);
	}
	
	override string _renderItem( ValueType value, string name, string name_attr )
	{
		import webtank.common.conv;
		return `<label><input type="checkbox" name="` ~ HTMLEscapeValue(name_attr) 
			~ `" value="` ~ value.conv!string ~ `"`
			~ ( _selectedValues.canFind(value) ? ` checked` : `` ) ~ `>`
			~ HTMLEscapeText(name) ~ `</label>` ~ "<br>\r\n";
	}
	
	///Метод генерирует разметку по заданным параметрам
	string print()
	{	
		import webtank.common.conv;
		
		string[string] spanAttrs;
			
		if( id.length > 0 )
			spanAttrs["id"] = id;
			
		if( classes.length > 0 )
			spanAttrs["class"] = HTMLEscapeValue( join(classes, ` `) );
			
		string output = `<span` ~ printHTMLAttributes(spanAttrs) ~ `>`;
		
		if( isNullable )
			output ~= `<label><input type="checkbox" name="` ~ HTMLEscapeValue(this.name) 
			~ `" value=""` ~ ( isNull ? ` checked` : `` ) ~ `>`
			~ HTMLEscapeText(nullName) ~ `</label>` ~ "<br>\r\n";
		
		output ~= _renderItems() ~ `</span>`;
		
		return output;
	}
	
	void selectedValues(ValueType[] values) @property
	{	_selectedValues = values;
	}
	
	ValueType[] selectedValues() @property
	{	return _selectedValues.dup;
	}
}

auto checkBoxList(T)(T valueSet)
{
	return new CheckBoxList!(T)(valueSet);
}

class RadioButtonList(ValueSetT)
{
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	this( ValueSetT set ) const
	{
		super(set);
	}
	
	this( ValueSetT set )
	{
		super(set);
	}
	
	private string _renderItem( ValueType value, string name, string name_attr )
	{
		import webtank.common.conv;
		return `<label><input type="radio" name="` ~ HTMLEscapeValue(name_attr) 
			~ `" value="` ~ value.conv!string ~ `"`
			~ ( _selectedValues.canFind(value) ? ` checked` : `` ) ~ `>`
			~ HTMLEscapeText(name) ~ `</label>` ~ "<br>\r\n";
	}
	
	///Метод генерирует разметку по заданным параметрам
	string print()
	{	
		import webtank.common.conv;
		
		string[string] spanAttrs;
			
		if( id.length > 0 )
			spanAttrs["id"] = id;
			
		if( classes.length > 0 )
			spanAttrs["class"] = HTMLEscapeValue( join(classes, ` `) );
			
		string output = `<span` ~ printHTMLAttributes(spanAttrs) ~ `>`;
		
		if( isNullable )
			output ~= `<label><input type="radio" name="` ~ HTMLEscapeValue(this.name) 
			~ `" value=""` ~ ( isNull ? ` checked` : `` ) ~ `>`
			~ HTMLEscapeText(nullName) ~ `</label>` ~ "<br>\r\n";
		
		output ~= _renderItems() ~ `</span>`;
		
		return output;
	}

}

auto radioButtonList(T)(T valueSet)
{
	return new RadioButtonList!(T)(valueSet);
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
			if( name.length > 0 ) //Путсые аттрибуты не записываем
				attrs["name"] = name ~ `__` ~ word;
		
		//Задаём доп. аттрибуты и значения для дня и месяца
		attrBlocks[`year`]["type"] = `text`;
		attrBlocks[`day`]["type"] = `text`;
		
		//Размеры окошечек для дня и года
		attrBlocks[`year`]["size"] = `4`;
		attrBlocks[`day`]["size"] = `2`;
		
		attrBlocks[`year`]["value"] = _date.year.isNull ? null : _date.year.to!string;
		attrBlocks[`day`]["value"] = _date.day.isNull ? null : _date.day.to!string;
		
		attrBlocks[`year`]["placeholder"] = nullYearName;
		attrBlocks[`day`]["placeholder"] = nullDayName;
		
		//Собираем строки окошечек для вывода
		string yearInp = `<input` ~ printHTMLAttributes(attrBlocks[`year`]) ~ `>`;
		string dayInp = `<input` ~ printHTMLAttributes(attrBlocks[`day`]) ~ `>`;
		
		string monthInp = `<select` ~ printHTMLAttributes(attrBlocks[`month`]) ~ `>`
			~ `<option value=""` ~ ( _date.month.isNull ? ` selected` : `` ) ~ `>`
			~ nullMonthName ~ `</option>`;
			
		assert( _monthNames.length == 12, `Month names array length must be 12!!!` );
		
		foreach( i, monthName; _monthNames )
		{	monthInp ~= `<option value="` ~ (i+1).to!string ~ `"`
			~ ( i+1 == _date.month ? ` selected` : `` )
			~ `>` ~ monthName ~ `</option>`;
		}
		monthInp ~= `</select>`;
		
		string[string] blockAttrs;
		
		if( id.length > 0 )
			blockAttrs["id"] = id;
			
		if( classes.length > 0 )
			blockAttrs["class"] = join(classes, ` `);
		
		return `<span` ~ printHTMLAttributes(blockAttrs) ~ `>`
			~ dayInp ~ ` ` ~ monthInp ~ ` ` ~ yearInp ~ `</span>`;
	}
	
	string nullDayName;
	string nullMonthName;
	string nullYearName;
	
	ref OptionalDate date() @property
	{	return _date;
	}

protected:
	OptionalDate _date;
	string[] _monthNames = months.dup;
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
