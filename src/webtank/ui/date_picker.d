module webtank.ui.date_picker;

import std.conv, std.datetime;

import webtank.common.optional;

import webtank.templating.plain_templater;
import webtank.ui.templating, webtank.ui.control;

static immutable months = 
	[	"январь", "февраль", "март", 
		"апрель", "май", "июнь", 
		"июль", "август", "сентябрь", 
		"октябрь", "ноябрь", "декабрь"
	];

class PlainDatePicker: BEMControl
{
	private static immutable _allowedElemsForClasses = [
		"block", "row", "day_field", "month_field", "year_field"
	];
	
	mixin AddClassesImpl;
	
private:
	static immutable _controlName = "PlainDatePicker";
	string _inputName;
	OptionalDate _date;
	static immutable _dateWords = [ "day", "month", "year" ];
	string _nullDayText;
	string _nullMonthText;
	string _nullYearText;

public:
	this() {}
	
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
	
	void date( OptionalDate value )
	{
		_date = value;
	}
	
	void nullDayText( string value )
	{
		_nullDayText = value;
	}
	
	void nullMonthText( string value )
	{
		_nullMonthText = value;
	}
	
	void nullYearText( string value )
	{
		_nullYearText = value;
	}
	
	string print()
	{
		auto tpl = getPlainTemplater( "ui/plain_date_picker.html" );
		auto itemTpl = getPlainTemplater( "ui/plain_date_picker_month.html" );
		
		string[][string] elemClasses = [
			"block": [ this.blockName, elementPrefix ~ `block`  ],
			"row": [ this.blockName, elementPrefix ~ `row` ],
			"day_field": [ this.blockName, elementPrefix ~ `day_field` ],
			"month_field": [ this.blockName, elementPrefix ~ `month_field` ],
			"month_item": [ this.blockName, elementPrefix ~ `month_item` ],
			"year_field": [ this.blockName, elementPrefix ~ `year_field` ]
		];

		import webtank.common.utils: getPtrOrSet;
		
		foreach( elemName; _allowedElemsForClasses )
		{
			if( auto classesPtr = elemName in _elementClasses )
				*elemClasses.getPtrOrSet(elemName) ~= *classesPtr;
		}
		
		//Задаём имена полей
		foreach( word; _dateWords )
			tpl.setHTMLValue( word ~ "_field_name",  _inputName ~ `__` ~ word );

		tpl.setHTMLValue( "day_value", _date.day.isNull ? null : _date.day.text );
		tpl.setHTMLValue( "day_placeholder", _nullDayText );
		
		tpl.setHTMLValue( "year_value", _date.year.isNull ? null : _date.year.text );
		tpl.setHTMLValue( "year_placeholder", _nullYearText );
		
		import std.array: join;

		string items;
		itemTpl.setHTMLValue( "month_item_value", null );
		itemTpl.setHTMLText( "month_item_text", _nullMonthText );
		itemTpl.setHTMLValue( "month_item_selected", _date.month.isNull ? "selected" : null );
		itemTpl.setHTMLValue( "month_item_cls", elemClasses.get("month_item", null).join(' ') );
		
		items ~= itemTpl.getString();
		
		foreach( i, month; months )
		{
			itemTpl.setHTMLValue( "month_item_value", (i + 1).text );
			itemTpl.setHTMLText( "month_item_text", month );
			itemTpl.setHTMLValue( "month_item_selected", i+1 == _date.month ? "selected" : null );
			itemTpl.setHTMLValue( "month_item_cls", elemClasses.get("month_item", null).join(' ') );
			
			items ~= itemTpl.getString();
		}
		
		foreach( elemName, elemClass; elemClasses )
			tpl.setHTMLValue( elemName ~ "_cls", elemClass.join(` `) );
		
		tpl.set( "month_list", items );
		
		return tpl.getString();
	}
}
 
