module webtank.view_logic.html_controls;

import std.conv, std.datetime, std.array, std.stdio, std.typecons;

import webtank.net.utils, webtank.datctrl.record_format;

class HTMLControl
{
	string name;  ///Имя поля ввода
	string[] classes; ///Набор HTML-классов присвоенных списку
	string id;  ///HTML-идентификатор поля ввода
}

///Простенький класс для генерации HTML-разметки для выпадающего списка элементов
class PlainDropDownList: HTMLControl
{	
	///Метод генерирует разметку по заданным параметрам
	string print()
	{	
		string[string] attrs;
		
		if( name.length > 0 )
			attrs["name"] = name;
			
		if( id.length > 0 )
			attrs["id"] = id;
			
		if( classes.length > 0 )
			attrs["class"] = HTMLEscapeValue( join(classes, ` `) );
		
		string output = `<select` ~ printHTMLAttributes(attrs) ~ `>`
			~ `<option value="null"` ~ ( _isNull ? ` selected` : `` ) ~ `>`
			~ HTMLEscapeText(values.defaultName) ~ `</option>`;
		
		foreach( name, key; values )
		{	output ~= `<option value="` ~ key.to!string ~ `"`
			~ ( ( !_isNull && key == _currKey  ) ? ` selected` : `` ) ~ `>`
			~ HTMLEscapeText(name) ~ `</option>`;
		}
		
		output ~= `</select>`;
		
		return output;
	}
	
	EnumFormat values; ///Значения выпадающего списка (перечислимый тип)
	
	int currKey() @property  ///Текущее значение списка
	{	return _currKey; }
	
	///Свойство: текущее значение списка
	void currKey(int value) @property
	{	_currKey = value;
		_isNull = false;
	}
	
	///Свойство для задания значения через std.typecons.Nullable
	void currKey(Nullable!(int) value) @property
	{	if( value.isNull() )
			_isNull = true;
		else
			_currKey = value.get();
	}
	
	bool isNull() @property
	{	return _isNull; }
	
	void nullify()
	{	_isNull = true; }

protected:
	bool _isNull = true;
	int _currKey;
}

enum string[] months = 
	[	"январь", "февраль", "март", 
		"апрель", "май", "июнь", 
		"июль", "август", "сентябрь", 
		"октябрь", "ноябрь", "декабрь"
	];

	
///Простой класс для создания HTML компонента выбора данных
///Состоит из двух текстовых полей (день, год) и выпадающего списка месяцев
class PlainDatePicker: HTMLControl
{	string print()
	{	
		string[string][string] attrBlocks = 
		[	`year`: null, `month`: null, `day`: null ];
		
		//Задаём базовые аттрибуты для окошечек календаря
		foreach( word, ref attrs; attrBlocks )
		{	if( name.length > 0 ) //Путсые аттрибуты не записываем
				attrs["name"] = name ~ `_` ~ word;
				
			if( id.length > 0 )
				attrs["id"] = id ~ `_` ~ word;
				
			if( classes.length > 0 )
				attrs["class"] = HTMLEscapeValue( join(classes, ` `) );
		}
		
		//Задаём доп. аттрибуты и значения для дня и месяца
		attrBlocks[`year`]["type"] = `text`;
		attrBlocks[`day`]["type"] = `text`;
		
		//Размеры окошечек для дня и года
		attrBlocks[`year`]["size"] = `4`;
		attrBlocks[`day`]["size"] = `2`;
		
		if( !_isNull )
		{	attrBlocks[`year`]["value"] = date.year.to!string;
			attrBlocks[`day`]["value"] = date.day.to!string;
		}
		
		//Собираем строки окошечек для вывода
		string yearInp = `<input` ~ printHTMLAttributes(attrBlocks[`year`]) ~ `>`;
		string dayInp = `<input` ~ printHTMLAttributes(attrBlocks[`day`]) ~ `>`;
		
		string monthInp = `<select` ~ printHTMLAttributes(attrBlocks[`month`]) ~ `>`
			~ `<option value="null"` ~ ( _isNull ? ` selected` : `` ) ~ `>`
			~ `Месяц не выбран</option>`;
		
		foreach( i, month; months )
		{	monthInp ~= `<option value="` ~ (i+1).to!string ~ `"`
			~ ( ( i+1 == date.month && !_isNull ) ? ` selected` : `` )
			~ `>` ~ month ~ `</option>`;
		}
		monthInp ~= `</select>`;
		
		return dayInp ~ ` ` ~ monthInp ~ ` ` ~ yearInp;
	}
	
	Date date() @property
	{	return _date;
	}
	
	void date(Date value) @property
	{	_date = value;
		_isNull = false;
	}
	
	bool isNull() @property
	{	return _isNull; }
	
	void nullify()
	{	_isNull = true; }

protected:
	bool _isNull = true;
	Date _date;
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

// void main()
// {	auto datePicker = new PlainDatePicker;
// // 	datePicker.name = "birth_date";
// // 	datePicker.id = "id";
// 	
// 	datePicker.date = Date(1996, 11, 20);
// 	datePicker.classes ~= "some_date";
// 	
// 	writeln(datePicker.print());
// 	
// 	auto dropdown = new PlainDropDownList;
// 	dropdown.values = [1: "первый", 2: "второй", 3: "третий"];
// 	dropdown.currValue = 2;
// 	dropdown.classes ~= ["something", "something_else"];
// 	
// 	writeln(dropdown.print());
// }
