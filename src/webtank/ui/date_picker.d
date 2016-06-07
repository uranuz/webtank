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

class PlainDatePicker: ITEMControl
{
	private static immutable _allowedElemsForClasses = [
		"block", "row", "day_field", "month_field", "year_field"
	];
	
	mixin ITEMControlBaseImpl;
	mixin AddElementHTMLClassesImpl;
	
private:
	static immutable _controlTypeName = "PlainDatePicker";
	static immutable _dateWords = [ "day", "month", "year" ];

	OptionalDate _date;
	string _nullDayText;
	string _nullMonthText;
	string _nullYearText;

public:
	this() {}
	
	override string controlTypeName() const @property
	{
		return _controlTypeName;
	}
	
	void date( OptionalDate value ) @property
	{
		_date = value;
	}
	
	void nullDayText( string value ) @property
	{
		_nullDayText = value;
	}
	
	void nullMonthText( string value ) @property
	{
		_nullMonthText = value;
	}
	
	void nullYearText( string value ) @property
	{
		_nullYearText = value;
	}
	
	string print()
	{
		auto tpl = getPlainTemplater( "ui/plain_date_picker.html" );
		auto itemTpl = getPlainTemplater( "ui/plain_date_picker_month.html" );
		
		string[][string] elemClasses = [
			"block": [ this.instanceHTMLClass, wtElementHTMLClassPrefix ~ `block` ] ~ _themeHTMLClasses,
			"row": [ this.instanceHTMLClass, wtElementHTMLClassPrefix ~ `row` ] ~ _themeHTMLClasses,
			"day_field": [ this.instanceHTMLClass, wtElementHTMLClassPrefix ~ `day_field` ] ~ _themeHTMLClasses,
			"month_field": [ this.instanceHTMLClass, wtElementHTMLClassPrefix ~ `month_field` ] ~ _themeHTMLClasses,
			"month_item": [ this.instanceHTMLClass, wtElementHTMLClassPrefix ~ `month_item` ] ~ _themeHTMLClasses,
			"year_field": [ this.instanceHTMLClass, wtElementHTMLClassPrefix ~ `year_field` ] ~ _themeHTMLClasses
		];

		import webtank.common.utils: getPtrOrSet;
		
		foreach( elemName; _allowedElemsForClasses )
		{
			if( auto classesPtr = elemName in _elementHTMLClasses )
				*elemClasses.getPtrOrSet(elemName) ~= *classesPtr;
		}
		
		//Задаём имена полей
		foreach( word; _dateWords )
			tpl.setHTMLValue( word ~ "_field_name",  _dataFieldName ~ `__` ~ word );

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

import webtank.common.optional: OptionalDate;

///Функция-помощник для создания простого компонента выбора даты
auto plainDatePicker( OptionalDate optDate = OptionalDate() )
{
	auto ctrl = new PlainDatePicker();
	ctrl.date = optDate;
	ctrl.addThemeHTMLClasses( "t-wt-PlainDatePicker" );

	return ctrl;
}