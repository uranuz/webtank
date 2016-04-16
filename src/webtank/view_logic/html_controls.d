module webtank.view_logic.html_controls;

import std.conv, std.datetime, std.array, std.stdio, std.typecons;

import webtank.net.utils, webtank.datctrl.record_format, webtank.datctrl.enum_format, webtank.common.optional;

//Block, Element, Modifier (BEM) concept prefixes for element classes
static immutable blockPrefix = `b-wui-`;
static immutable elementPrefix = `e-wui-`;
static immutable modifierPrefix = `m-wui-`;

class HTMLControl
{
	string name;  ///Имя поля ввода
	string[] classes; ///Набор HTML-классов присвоенных списку
	string id;  ///HTML-идентификатор поля ввода
	protected string _componentName; ///Название элемента управления в CSS
	
	this(string cssName) pure
	{
		_componentName = cssName;
	}
	
	string componentName() @property
	{
		return _componentName;
	}
	
	string blockName() @property
	{
		return blockPrefix ~ _componentName;
	}
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
	
	this( ValueSetT set, string cssName ) pure
	{
		if( cssName.length > 0 )
			super(cssName);
		else
			super("list_control");
			
		_valueSet = set;
	}
	
	abstract string _renderItem( ValueType value, string name_attr );
	abstract string _renderNullItem();
	
	string _renderItems()
	{
		string output;
		
		if( isNullable )
			output ~= _renderNullItem();
		
		foreach( name, value; _valueSet )
		{
			static if( isEnumFormat!(ValueSetType) )
			{
				output ~= _renderItem(value, name);
			}
			else static if( isArray!(ValueSetType) )
			{
				static if( hasNames )
					output ~= _renderItem(value, name);
				else
					output ~= _renderItem(value, value.conv!string);
			}
		}

		return output;
	}
	
	
	void selectedValue(ValueType value) @property
	{	_selectedValues = [value];
	}
	
	void selectedValue(Optional!ValueType value) @property
	{
		if( value.isNull )
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
	
	void addItemClass(string cls)
	{
		_itemClasses ~= cls;
	}
	
	void addItemClasses(string[] classes)
	{
		_itemClasses ~= classes;
	}
	
	string print() {
		return `<div class='` ~ this.blockName ~ `'></div>`;
	}

protected:
	bool _isNullable = true;
	string _nullName;
	ValueType[] _selectedValues;
	ValueSetType _valueSet;
	string[] _itemClasses;
}

///Простенький класс для генерации HTML-разметки для выпадающего списка элементов
class ListBox(ValueSetT): HTMLListControl!(ValueSetT)
{	
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	this( ValueSetT set ) pure
	{
		super(set, "ListBox");
	}
	
	override string _renderItem( ValueType value, string name_attr )
	{	return _customRenderItem(value, name_attr);
	}
	
	override string _renderNullItem()
	{	return _customRenderItem( null, HTMLEscapeText(nullName) );
	}
	
	string _customRenderItem(V)(V value, string name_attr) 
	{
		import webtank.common.conv, std.algorithm: canFind;
		string[string] optAttrs = [ `name`: this.name ];
		string[] optClasses = [ 
			blockName,
			elementPrefix ~ `ListItem`
		];

		static if( is( V == typeof(null) ) ) 
		{
			optAttrs[`value`] = ``; //Лучше явно задать
			optClasses ~= [ modifierPrefix ~ `isNullValue` ];
			
			if( this.isNull )
				optAttrs[`selected`] = ``;
		}
		else
		{
			optAttrs[`value`] = value.conv!string;
			
			if( _selectedValues.canFind(value) )
				optAttrs[`selected`] = ``;
		}
		optAttrs[`class`] = optClasses.join(` `);
		
		return `<option` ~ printHTMLAttributes(optAttrs) ~ `>` ~ HTMLEscapeText(name_attr) ~ `</option>`;
	}
	
	///Метод генерирует разметку по заданным параметрам
	override string print()
	{	
		import webtank.common.conv;
		string[string] selectAttrs;
		
		if( name.length > 0 )
			selectAttrs["name"] = name;
			
		if( id.length > 0 )
			selectAttrs["id"] = id;
		
		string[] clsList = classes ~ [this.blockName];
		
		if( clsList.length > 0 )
			selectAttrs["class"] = HTMLEscapeValue( join(clsList, ` `) );
			
		if( isMultiSelect )
			selectAttrs["multiple"] = null;
			
		return `<select` ~ printHTMLAttributes(selectAttrs) ~ `>` ~ _renderItems() ~ `</select>`;
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
}

auto listBox(T)(T valueSet)
{
	return new ListBox!(T)(valueSet);
}

class CheckableInputList(ValueSetT, bool isRadio): HTMLListControl!(ValueSetT)
{
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	this( ValueSetT set ) pure
	{
		static if( isRadio )
			super(set, "RadioButtonList");
		else
			super(set, "CheckBoxList");
	}
	
	override string _renderItem( ValueType value, string name_attr )
	{	return _customRenderItem(value, name_attr);
	}
	
	override string _renderNullItem()
	{	return _customRenderItem( null, HTMLEscapeText(nullName) );
	}
	
	string _customRenderItem(V)(V value, string name_attr) 
	{
		static if( isRadio )
		{
			enum inputType = `radio`;
		}
		else
		{
			enum inputType = `checkbox`;
		}
		
		import webtank.common.conv, std.algorithm: canFind;
		string[string] inputAttrs = [ 
			`name`: this.name,
			`type`: inputType
		];
		string[string] labelAttrs;
		string[string] listItemAttrs;
		string[string] labelTextAttrs;
		
		string[] inputClasses = [ 
			this.blockName,
			elementPrefix ~ `ListItem_input`
		];
		string[] labelClasses = [
			this.blockName,
			elementPrefix ~ `ListItem_label`
		];
		labelClasses ~= this._itemClasses;
		
		string[] listItemClasses = [
			this.blockName,
			elementPrefix ~ `ListItem`
		];
		string[] labelTextClasses = [
			this.blockName,
			elementPrefix ~ `ListItem_labelText`
		];

		static if( is( V == typeof(null) ) ) 
		{
			inputAttrs[`value`] = ``; //Лучше явно задать
			listItemClasses ~= [ modifierPrefix ~ `isNullValue` ];
			
			if( this.isNull )
				inputAttrs[`checked`] = ``;
		}
		else
		{
			inputAttrs[`value`] = value.conv!string;
			
			if( _selectedValues.canFind(value) )
				inputAttrs[`checked`] = ``;
		}
		inputAttrs[`class`] = inputClasses.join(` `);
		labelAttrs[`class`] = labelClasses.join(` `);
		listItemAttrs[`class`] = listItemClasses.join(` `);
		labelTextAttrs[`class`] = labelTextClasses.join(` `);
		
		return `<div` ~ printHTMLAttributes(listItemAttrs) ~ `><label` ~ printHTMLAttributes(labelAttrs) 
			~ `><input` ~ printHTMLAttributes(inputAttrs) ~ `>`
			~ `<span` ~ printHTMLAttributes(labelTextAttrs) ~ `>` 
			~ HTMLEscapeText(name_attr) ~ `</span></label></div>` ~ "\r\n";
	}

	///Метод генерирует разметку по заданным параметрам
	override string print()
	{	
		import webtank.common.conv;
		
		string[string] spanAttrs;
			
		if( id.length > 0 )
			spanAttrs["id"] = id;
			
		string[] clsList = classes ~ [this.blockName];
			
		if( clsList.length > 0 )
			spanAttrs["class"] = HTMLEscapeValue( join(clsList, ` `) );
			
		return `<span` ~ printHTMLAttributes(spanAttrs) ~ `>` ~ _renderItems() ~ `</span>`;
	}
	
	static if( !isRadio )
	{
		void selectedValues(ValueType[] values) @property
		{	_selectedValues = values;
		}
		
		ValueType[] selectedValues() @property
		{	return _selectedValues.dup;
		}
	}
}

alias CheckBoxList(ValueSetT) = CheckableInputList!(ValueSetT, false);
alias RadioButtonList(ValueSetT) = CheckableInputList!(ValueSetT, true);

///Функция-помощник для создания списка флагов
auto checkBoxList(T)(T valueSet)
{
	return new CheckBoxList!(T)(valueSet);
}

///Функция-помощник для создания списка радиокнопок
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
	this() pure
	{
		super("PlainDatePicker");
	}
	
	string print()
	{	
		string[string][string] attrBlocks = 
		[	`year`: null, `month`: null, `day`: null ];
		
		//Задаём базовые аттрибуты для окошечек календаря
		foreach( word, ref attrs; attrBlocks )
			if( name.length > 0 ) //Пустые аттрибуты не записываем
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
		
		string[] clsList = classes ~ [this.blockName];
			
		if( clsList.length > 0 )
			blockAttrs["class"] = join(clsList, ` `);
		
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
