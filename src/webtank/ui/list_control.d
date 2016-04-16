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

class ListControl(ValueSetT): BEMControl
{
public:
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	this( ValueSetT set, string ctrlName ) pure
	{
		_valueSet = set;
		_controlName = ctrlName;
	}
	
	override string controlName() @property
	{
		return _controlName;
	}
	
	override void dataFieldName(string value) @property
	{
		_inputName = value;
	}
	
	override string blockName() @property
	{
		return blockPrefix ~ _controlName;
	}
	
	override abstract void addElementClasses( string element, string classes );
	
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
	
	override string print()
	{
		return null;
	}
	
protected:
	string _controlName;
	string _inputName;
	bool _isNullable = true;
	string _nullText;
	ValueType[] _selectedValues;
	ValueSetType _valueSet;
}

class CheckableInputList(ValueSetT, bool isRadio): ListControl!(ValueSetT)
{
	mixin AddClassesImpl;

public:
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	private static immutable _allowedElemsForClasses = [
		"item_input", "item_label", "list_item", "item_caption", "block"
	];
	
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
		
		tpl.setHTMLValue( "input_name", this._inputName );
		tpl.setHTMLValue( "input_type", inputType );
		tpl.setHTMLText( "caption_text", name_attr );
		
		string[][string] elemClasses = [
			"block": [
				this.blockName,
				elementPrefix ~ `block`
			],
			"list_item": [
				this.blockName,
				elementPrefix ~ `list_item`
			],
			"item_input": [ 
				this.blockName,
				elementPrefix ~ `item_input`
			],
			"item_label": [
				this.blockName,
				elementPrefix ~ `item_label`
			],
			"item_caption": [
				this.blockName,
				elementPrefix ~ `item_caption`
			]
		];
		
		import webtank.common.utils: getPtrOrSet;
		
		foreach( elemName; _allowedElemsForClasses )
		{
			if( auto classesPtr = elemName in _elementClasses )
				*elemClasses.getPtrOrSet(elemName) ~= *classesPtr;
		}

		static if( is( V == typeof(null) ) ) 
		{
			tpl.setHTMLValue( "input_value", null ); //Лучше явно задать
			elemClasses["wrapper"] ~= [ modifierPrefix ~ `isNullValue` ];
			
			tpl.setHTMLValue( "input_checked", 
				this.isNull ? "checked" : null );
		}
		else
		{
			import webtank.common.conv;
			import std.algorithm: canFind;
			
			tpl.setHTMLValue( "input_value", value.conv!string );
			tpl.setHTMLValue( "input_checked", 
				_selectedValues.canFind(value) ? "checked" : null );
		}
		
		foreach( elemName, elemClass; elemClasses )
			tpl.setHTMLValue( elemName ~ "_cls", elemClass.join(` `) );
		
		return tpl.getString();
	}

	///Метод генерирует разметку по заданным параметрам
	override string print()
	{	
		import webtank.common.conv;
		auto tpl = getPlainTemplater( "ui/checkable_input_list.html" );
		
		string[] blockClasses = [this.blockName];
		
		if( auto elemPtr = "block" in _elementClasses )
		{
			blockClasses ~= *elemPtr;
		}
		
		tpl.set( "list_items", _renderItems() );
		tpl.setHTMLValue( "block_cls", blockClasses.join(` `) );

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
	return new CheckBoxList!(T)(valueSet);
}

///Функция-помощник для создания списка радиокнопок
auto radioButtonList(T)(T valueSet)
{
	return new RadioButtonList!(T)(valueSet);
}

///Простенький класс для генерации HTML-разметки для выпадающего списка элементов
class ListBox(ValueSetT): ListControl!(ValueSetT)
{	
	mixin AddClassesImpl;

public:
	alias ValueSetType = ValueSetT;
	alias ValueSetSpec = HTMLListControlValueSetSpec!ValueSetType;
	alias ValueType = ValueSetSpec.ValueType;
	enum bool hasNames = ValueSetSpec.hasNames;
	
	private static immutable _allowedElemsForClasses = [
		"select", "option"
	];
	
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
		auto tpl = getPlainTemplater( "ui/checkable_input_list_item.html" );

		tpl.setHTMLValue( "option_name", _inputName );
		
		string[][string] elemClasses = [
			"block": [
				this.blockName,
				elementPrefix ~ `block`
			],
			"list_item": [
				this.blockName,
				elementPrefix ~ `list_item`
			],
			"item_input": [ 
				this.blockName,
				elementPrefix ~ `item_input`
			],
			"item_label": [
				this.blockName,
				elementPrefix ~ `item_label`
			],
			"item_caption": [
				this.blockName,
				elementPrefix ~ `item_caption`
			]
		];
		
		import webtank.common.utils: getPtrOrSet;
		
		foreach( elemName; _allowedElemsForClasses )
		{
			if( auto classesPtr = elemName in _elementClasses )
				*elemClasses.getPtrOrSet(elemName) ~= *classesPtr;
		}
		
		import webtank.common.conv, std.algorithm: canFind;

		static if( is( V == typeof(null) ) ) 
		{
			tpl.setHTMLValue( "option_value", null ); //Лучше явно задать
			elemClasses["option_cls"] ~= [ modifierPrefix ~ `isNullValue` ];
			tpl.setHTMLText( "option_text", _nullText );
			tpl.setHTMLValue( "option_selected", this.isNull ? `selected` : null );
		}
		else
		{
			tpl.setHTMLValue( "option_value", value.conv!string );
			tpl.setHTMLText( "option_text", name_attr );
			tpl.setHTMLValue( "option_selected", _selectedValues.canFind(value) ? `selected` : null );
		}
		
		foreach( elemName, elemClass; elemClasses )
			tpl.setHTMLValue( elemName ~ "_cls", elemClass.join(` `) );
		
		return tpl.getString();
	}
	
	///Метод генерирует разметку по заданным параметрам
	override string print()
	{	
		auto tpl = getPlainTemplater( "ui/checkable_input_list_item.html" );
		
		tpl.setHTMLValue( "select_name", _inputName );
		
		import webtank.common.conv;
		string[string] selectAttrs;
		
		string[] selectClasses = [this.blockName];
		
		if( auto elemPtr = "select" in _elementClasses )
		{
			selectClasses ~= *elemPtr;
		}
		
		tpl.setHTMLValue( "select_cls", selectClasses.join(' ') );
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
	return new ListBox!(T)(valueSet);
}