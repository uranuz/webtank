module webtank.templating.plain_templater_datctrl;

import webtank.templating.plain_templater, webtank.datctrl.record, webtank.datctrl.record_format;

///Функция записывает данные из записи rec в шаблон tpl. 
///Могут быть переданы доп. аттрибуты attrs бля управления заполнением шаблона данными.
///По-умолчанию строковые поля обрабатываются через HTMLEscape
void fillFrom(Rec)( PlainTemplater tpl, Rec rec, FillAttrs attrs = FillAttrs() )
{
	import std.conv: to;
	import std.traits: isSomeString;
	import webtank.net.utils: HTMLEscapeValue;
	import webtank.datctrl.enum_format: isEnumFormat;
	foreach( fieldName; Rec.FormatType.tupleOfNames!() )
	{
		alias fieldType = Rec.FormatType.getValueType!(fieldName);
		alias fieldFormatDecl = Rec.FormatType.getFieldFormatDecl!(fieldName);
		if( !tpl.hasElement(fieldName) )
			continue; //Не засоряем контекст шаблона неиспользуемыми данными
		
		if( rec.isNull(fieldName) )
		{
			if( fieldName in attrs.defaults )
				tpl.set( fieldName, attrs.defaults[fieldName] );
		}
		else
		{
			static if( isEnumFormat!(fieldFormatDecl) )
			{
				//auto enumFormat = rec.getEnumFormat!(fieldName)();
				//string value = enumFormat.getName( rec.get!(fieldName)() );
				string value = rec.getStr!(fieldName)();
			}
			else static if( isSomeString!( fieldType ) ) //Needs escaping
			{
				import std.algorithm: canFind;
				string value = rec.get!(fieldName)().to!string;
				
				if( !attrs.noEscaped.canFind(fieldName) )
					value = HTMLEscapeValue( value );
			}
			else
			{
				string value = rec.get!(fieldName)().to!string;
			}
			tpl.set(fieldName, value);
		}
	}
}

///
struct FillAttrs
{
	///Список строковых полей записи, которые не обрабатываются через HTMLEscape,
	///т.е. которые выводятся как есть
	string[] noEscaped;
	
	///Словарь со значениями по-умолчанию для полей записи
	string[string] defaults;
}