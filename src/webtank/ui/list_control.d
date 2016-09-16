module webtank.ui.list_control;

import std.conv, std.datetime, std.array;

import 
	webtank.net.utils, 
	webtank.datctrl.record_format, 
	webtank.datctrl.enum_format, 
	webtank.common.optional;
	
import webtank.templating.plain_templater;
import webtank.ui.templating, webtank.ui.control;

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

/**
Требования к списочным компонентам:
	1. Нужна возможность отображения "элемента сброса" в списке, который по активации выполняет сброс выбранных значений
	для всего компонента в состояние "пусто", "не задано", "начальное состояние". В случае, если выбран какой-либо другой
	элемент, то этот "элемент сброса" деактивируется
	2. Для компонентов множественного выбора (multiselect) нужна возможность отображения отдельной кнопки-переключателя,
	которая по активации либо сбрасывает значения в "начальное состояние", либо выбирает все элементы в списке
	(кроме "элемента сброса" из п. 1). Переключатель также может находиться в неопределеном состоянии, когда выбрана
	часть элементов из списка
	3. Нужна поддержка типов значений из ValueSet, которые могут иметь null-значение. Это значение при этом играет
	самостоятельную роль и не связано со сбросом всех значений в списка. Например, это может понадобиться, когда
	с помощью компонента мы хотим указать, что нужно отобрать элементы, у которых значение равно null, либо
	каким-то еще другим значения из списка.

*/

///Базовый абстрактный класс для списочных компонентов
class ListControl(ValueSetT): ITEMControl
{
	mixin ITEMControlBaseImpl;

public:
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	this( ValueSetT set, string ctrlTypeName ) pure
	{
		_valueSet = set;
		_controlTypeName = ctrlTypeName;
	}
	
	override string controlTypeName() const @property
	{
		return _controlName;
	}
	
	abstract void addElementHTMLClasses( string element, string classes );
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
	
	string nullText() @property
	{	return _nullText;
	}
	
	void nullText(string value) @property
	{	_nullText = value;
	}
	
	void setNullable(bool value)
	{	_isNullable = value;
	}
	
	void nullify()
	{	_selectedValues = null;
	}

	bool hasMasterSwitch() @property
	{	return _hasMasterSwitch;
	}

	void hasMasterSwitch(bool value) @property
	{	_hasMasterSwitch = value;
	}

	string masterSwitchText() @property
	{	return _masterSwitchText;
	}

	void masterSwitchText(string value) @property
	{	_masterSwitchText = value;
	}
	
	override string print()
	{
		return null;
	}
	
protected:
	string _controlTypeName;
	bool _isNullable = true;
	bool _hasMasterSwitch = true;
	string _nullText;
	string _masterSwitchText;
	ValueType[] _selectedValues;
	ValueSetType _valueSet;
}

private alias getZeroItemPred = a => a[0];

class CheckableInputList(ValueSetT, bool isRadio): ListControl!(ValueSetT)
{
public:
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;

	private static immutable _listItemElements = [
		"list_item", "item_input", "item_label", "item_caption"
	];

	import std.typecons: tuple;

	private static immutable _masterSwitchElemsMap = [
		tuple("master_switch_item", "list_item"),
		tuple("master_switch_input", "item_input"),
		tuple("master_switch_label", "item_label"),
		tuple("master_switch_caption", "item_caption")
	];

	import std.algorithm: map;
	import std.array: array;

	private static immutable _allowedElemsForClasses =
		_listItemElements
		~ [ "block", "scroll_box", "container" ]
		~ _masterSwitchElemsMap.map!getZeroItemPred().array();

	mixin AddElementHTMLClassesImpl;
	
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
	{	return _customRenderItem( null, HTMLEscapeText(nullText) );
	}
	
	string _customRenderItem(V)(V value, string name_attr) 
	{
		auto tpl = getPlainTemplater( "ui/checkable_input_list_item.html" );
		
		static if( isRadio )
		{
			static immutable inputType = `radio`;
		}
		else
		{
			static immutable inputType = `checkbox`;
		}
		
		tpl.setHTMLValue( "input_name", this._dataFieldName );
		tpl.setHTMLValue( "input_type", inputType );
		tpl.setHTMLText( "caption_text", name_attr );
		
		static if( is( V == typeof(null) ) ) 
		{
			tpl.setHTMLValue( "input_value", null ); //Лучше явно задать
			//elemClasses["wrapper"] ~= [ wtModifierHTMLClassPrefix ~ `is-null_value` ];
			
			tpl.setHTMLValue( "input_checked", this.isNull ? "checked" : null );
		}
		else
		{
			import webtank.common.conv;
			import std.algorithm: canFind;
			
			tpl.setHTMLValue( "input_value", value.conv!string );
			tpl.setHTMLValue( "input_checked", _selectedValues.canFind(value) ? "checked" : null );
		}
		
		foreach( elem; _listItemElements )
			tpl.setHTMLValue( elem ~ "_cls", _printHTMLClasses(elem) );
		
		return tpl.getString();
	}

	///Метод генерирует разметку по заданным параметрам
	override string print()
	{	
		import webtank.common.conv;
		import std.algorithm: canFind;
		auto tpl = getPlainTemplater( "ui/checkable_input_list.html" );

		tpl.setHTMLValue( "master_switch_cls", _printHTMLClasses("master_switch") );

		static if( !isRadio )
		{
			if( this.hasMasterSwitch )
			{
				bool isAllSelected = true;

				foreach( name, value; _valueSet )
				{
					if( !_selectedValues.canFind(value) )
						isAllSelected = false;
				}

				auto switchTpl = getPlainTemplater( "ui/checkable_input_list_item.html" );

				switchTpl.setHTMLValue( "input_type", "checkbox" );
				switchTpl.setHTMLText( "caption_text", _masterSwitchText );
				switchTpl.setHTMLValue( "input_checked", isAllSelected ? "checked" : null );

				foreach( elem; _masterSwitchElemsMap )
					switchTpl.setHTMLValue( elem[1] ~ "_cls", _printHTMLClasses(elem[0]) );

				tpl.set( "master_switch", switchTpl.getString() );
			}
		}

		tpl.set( "list_items", _renderItems() );

		foreach( elem;  ["block", "scroll_box", "container"] )
			tpl.setHTMLValue( elem ~ "_cls", _printHTMLClasses(elem) );

		return tpl.getString();
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
	auto ctrl = new CheckBoxList!(T)(valueSet);
	ctrl.addThemeHTMLClasses( "t-wt-CheckBoxList" );

	return ctrl;
}

///Функция-помощник для создания списка радиокнопок
auto radioButtonList(T)(T valueSet)
{
	auto ctrl = new RadioButtonList!(T)(valueSet);
	ctrl.addThemeHTMLClasses( "t-wt-RadioButtonList" );

	return ctrl;
}

///Класс для генерации HTML-разметки для выпадающего списка элементов
class ListBox(ValueSetT): ListControl!(ValueSetT)
{	
public:
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	private static immutable _allowedElemsForClasses = [
		"select", "option"
	];

	mixin AddElementHTMLClassesImpl;
	
	this( ValueSetT set ) pure
	{
		super(set, "ListBox");
	}
	
	override string _renderItem( ValueType value, string name_attr )
	{	return _customRenderItem(value, name_attr);
	}
	
	override string _renderNullItem()
	{	return _customRenderItem( null, HTMLEscapeText(nullText) );
	}
	
	string _customRenderItem(V)(V value, string name_attr) 
	{
		auto tpl = getPlainTemplater( "ui/list_box_item.html" );

		tpl.setHTMLValue( "option_name", _dataFieldName );
		
		import webtank.common.conv, std.algorithm: canFind;

		static if( is( V == typeof(null) ) ) 
		{
			tpl.setHTMLValue( "option_value", null ); //Лучше явно задать
			//elemClasses["option_cls"] ~= [ wtModifierHTMLClassPrefix ~ `is-null_value` ];
			tpl.setHTMLText( "option_text", _nullText );
			tpl.setHTMLValue( "option_selected", this.isNull ? `selected` : null );
		}
		else
		{
			tpl.setHTMLValue( "option_value", value.conv!string );
			tpl.setHTMLText( "option_text", name_attr );
			tpl.setHTMLValue( "option_selected", _selectedValues.canFind(value) ? `selected` : null );
		}
		
		tpl.setHTMLValue( "option_cls", _printHTMLClasses("option") );
		
		return tpl.getString();
	}
	
	///Метод генерирует разметку по заданным параметрам
	override string print()
	{	
		auto tpl = getPlainTemplater( "ui/list_box.html" );
		
		tpl.setHTMLValue( "select_name", _dataFieldName );
		tpl.setHTMLValue( "select_cls", _printHTMLClasses("select") );
		tpl.setHTMLValue( "select_multiple", isMultiSelect ? `multiple` : null );
		tpl.set( "list_items", _renderItems() );
		
		return tpl.getString();
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
	auto ctrl = new ListBox!(T)(valueSet);
	ctrl.addThemeHTMLClasses( "t-wt-ListBox" );

	return ctrl;
}
