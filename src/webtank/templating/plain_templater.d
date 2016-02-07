module webtank.templating.plain_templater;

/**
	Пример шаблона:
*/
dstring testTemplateStr = `
	<html>
	<head>
	<title>{{browserTitle}}</title>
	<meta charset="{{encoding}}">
	<link rel="stylesheet" type="text/css" href="{{stylesheet}}"/>
	</head>
	{{?page_title:=hello}}
	{{?user_name:=vasya}}
		
	<body>
	<div id="header">{{header}}</div>
	<div id="sidebar">{{sidebar}}</div>
	<div id="content">{{content}}</div>
	<div id="footer">{{footer}}</div>
	</body>
	</html>`d;

class Element
{	immutable(size_t) prePos;
	immutable(size_t) sufPos;
	immutable(size_t) matchOpPos;
	this( size_t prefixPos, size_t suffixPos, size_t matchOperatorPos = size_t.max )
	{	prePos = prefixPos; sufPos = suffixPos; matchOpPos = matchOperatorPos; }
	bool isVar() @property const
	{	return matchOpPos != size_t.max;
	}
}

enum LexemeType 
{	markPre, markSuf, varPre, matchOp, varSuf };

immutable(dstring[LexemeType]) defaultLexems;

static this()
{	with( LexemeType )
	{
	defaultLexems = [
		markPre: "{{", markSuf: "}}", 
		varPre: "{{?", matchOp: ":=", varSuf: "}}" 
	];
	} //with( LexemeType )
}

class PlainTemplate
{
//private;
	Element[][dstring] _namedEls;
	Element[] _indexedEls;
	dstring _sourceStr;
	immutable(dstring[LexemeType]) _lexValues;
	
public:
	this( string templateStr, immutable(dstring[LexemeType]) lexems = defaultLexems )
	{	import std.utf;
		_lexValues = lexems;
		_sourceStr = std.utf.toUTF32(templateStr);
		_parseTemplateStr();
	}

private:
	void _parseTemplateStr()
	{	
		import std.algorithm: startsWith;
		
		size_t prefixPos;
		size_t matchOpPos;
		bool markPreFound = false;
		bool varMatchOpFound = false;
		bool varPreFound = false;
		
		for( size_t i = 0; i < _sourceStr.length; ++i )
		{	dstring[LexemeType] selLexemes;
			foreach( lexType, curLexValue; _lexValues )
			{	if( _sourceStr[i..$].startsWith(curLexValue) )
				{
					//Если нашли, то добавляем в сортированный список новый элемент
					bool checked = true;
					switch( lexType ) with( LexemeType )
					{	
						case matchOp: {
							checked = varPreFound;
							break;
						}
						case varSuf: {
							checked = varPreFound && varMatchOpFound;
							break;
						}
						case markSuf: {
							checked = markPreFound;
							break;
						}
						default:
							break;
					}
					if( checked )
						selLexemes[lexType] ~= curLexValue;
				}
			}
			
			//Если ни одной лексемы не найдено, то идём дальше
			if( selLexemes.length <= 0 )
				continue;
			//Из всех найденных лексем будем брать самую длинную
			size_t largestLexLen;
			LexemeType selLexType;
			foreach( lexType, curLexValue; selLexemes )
			{	if( curLexValue.length > largestLexLen )
				{	largestLexLen = curLexValue.length;
					selLexType = lexType;
				}
			}
			
			switch( selLexType ) with( LexemeType )
			{
				case matchOp: {
					varMatchOpFound = true;
					matchOpPos = i;
					break;
				}
				case varPre: {
					varPreFound = true;
					prefixPos = i;
					break;
				}
				case varSuf: {
					import std.string;
					auto elemName = std.string.strip(
						_sourceStr[ (prefixPos + _lexValues[varPre].length) .. matchOpPos ]
					);
					auto elem = new Element(prefixPos, i, matchOpPos);
					_namedEls[elemName] ~= elem;
					_indexedEls ~= elem;
					varMatchOpFound = false;
					varPreFound = false;
					break;
				}
				case markPre: {
					markPreFound = true;
					prefixPos = i;
					break;
				}
				case markSuf: {
					import std.string;
					auto elemName = std.string.strip(
						_sourceStr[ (prefixPos + _lexValues[markPre].length) .. i ]
					);
					auto elem = new Element(prefixPos, i);
					_namedEls[elemName] ~= elem;
					_indexedEls ~= elem;
					markPreFound = false;
					break;
				}
				default:
				
				break;
			}
		}
	}
	
	size_t lexLen(LexemeType lexType) const
	{
		return _lexValues[lexType].length;
	}
	
	public string getString(const dstring[dstring] values, size_t extraSize = 0) const
	{	import std.utf;
		import std.array: appender;
		
		auto result = appender!dstring();
		result.reserve( _sourceStr.length + extraSize );
		//dstring result;
		size_t textStart = 0;
		dstring markName;
		foreach(el; _indexedEls)
		{	
			if( el.isVar )
			{	result ~= _sourceStr[textStart .. el.prePos];
				textStart = el.sufPos + lexLen(LexemeType.varSuf);
			}
			else
			{	markName = std.string.strip( 
					_sourceStr[ el.prePos + lexLen(LexemeType.markPre) .. el.sufPos ]
				);
				result ~= _sourceStr[textStart .. el.prePos] ~ values.get(markName, null);
				textStart = el.sufPos + lexLen(LexemeType.markSuf);
			}
		}
		result ~= _sourceStr[textStart .. $];
		return std.utf.toUTF8( result.data() );
		//return std.utf.toUTF8( result );
	}
}


class PlainTemplater
{	
private:
	PlainTemplate _tpl;
	dstring[dstring] _values;
	size_t _extraDataSizeEval; //Доп. объем данных которые могут быть записаны в вывод
	
public:
	this( string templateStr, immutable(dstring[LexemeType]) lexemes = defaultLexems )
	{	
		_tpl = new PlainTemplate(templateStr, lexemes);
	}
	
	this(PlainTemplate tpl)
	{
		_tpl = tpl;
	}
	
	//Устанавливает замещающее значение value для метки с именем markName
	void set(string markName, string value)
	{	import std.utf;
		dstring markNameUTF32 = std.string.strip( std.utf.toUTF32(markName) );
		dstring valueUTF32 = std.utf.toUTF32( value );
		
		//Собираем оценку хранимых данных
		//Если по новой задаем переменную, то вычитаем предыдущий размер данных из оценки размера
		size_t oldValueSize = _values.get(markNameUTF32, null).length;
		
		if( _extraDataSizeEval >= oldValueSize ) //Перестраховка, чтобы не было переполнения при вычитании (хотя не должно быть!)
			_extraDataSizeEval -= oldValueSize;
			
		_extraDataSizeEval += valueUTF32.length;
		
		_values[markNameUTF32] = valueUTF32;
	}
	
	//Получение значения из переменной с именем name
	string get(string name) const
	{	import std.utf;
		dstring nameUTF32 = std.utf.toUTF32(name);
		if( (nameUTF32 in _tpl._namedEls) && (_tpl._namedEls[nameUTF32].length > 0) )
		{	auto el = _tpl._namedEls[nameUTF32][0];
			if( el.isVar )
				return 
					std.utf.toUTF8( _tpl._sourceStr[ ( el.matchOpPos + _tpl.lexLen(LexemeType.matchOp) ) .. el.sufPos ] );
			else 
				return null;
		}
		else 
			return null;
	}
	
	string getString() const
	{
		return _tpl.getString(_values, _extraDataSizeEval);
	}

}

class PlainTemplateCache(bool useCache = true)
{
private:
	import core.sync.mutex;
	PlainTemplate[string] _tpls;
	
	Mutex _mutex;
	
public:
	this()
	{
		_mutex = new Mutex();
	}
	
	PlainTemplater get(string fileName)
	{
		import std.file: read, exists, FileException;

		static if( useCache )
		{
			PlainTemplate tpl;
			
			if( fileName in _tpls )
			{
				tpl = _tpls[fileName];
			}
			else
			{
				if( !exists(fileName) )
					throw new FileException(fileName, "Template file '" ~ fileName ~ "' not found!");
				
				synchronized( _mutex )
				{
					string templateStr = cast(string) read( fileName );
					tpl = new PlainTemplate(templateStr);
					_tpls[fileName] = tpl;
				}
			}
			
			return new PlainTemplater( tpl );
		}
		else
		{
			if( !exists(fileName) )
				throw new FileException(fileName, "Template file '" ~ fileName ~ "' not found!");
			
			string templateStr = cast(string) read( fileName );
			return new PlainTemplater( templateStr );
		}
	}

}

