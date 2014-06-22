module webtank.net.uri_pattern;

import std.stdio, std.conv;

import std.utf, std.algorithm, std.regex;

struct URIMatchingData
{	dstring[dstring] params;
	bool isMatched = false;
}

class URIPattern
{	
	this( string URIPatternStr, string[string] regExprs, string[string] defaults )
	{	_lexemes = parseURIPattern( toUTF32(URIPatternStr) );
		
		foreach( paramName, expr; regExprs )
			_regExprs[ toUTF32(paramName) ] = toUTF32(expr);
		
		foreach( paramName, value; defaults )
			_defaults[ toUTF32(paramName) ] = toUTF32(value);
	}
	
	this( string URIPatternStr, string[string] defaults = null )
	{	_lexemes = parseURIPattern( toUTF32(URIPatternStr) );
		
		foreach( paramName, value; defaults )
			_defaults[ toUTF32(paramName) ] = toUTF32(value);
	}
	
	URIMatchingData match(string URIStr)
	{	return matchURI( std.utf.toUTF32(URIStr), _lexemes, _regExprs, _defaults );
	}
	
protected:
	dstring[] _lexemes;
	dstring[dstring] _regExprs;
	dstring[dstring] _defaults;

}


dstring[] parseURIPattern(dstring URIPatternStr)
{
	dstring[] result;
	size_t i = 0;

	size_t lexemePos = 0;
	bool isNameStarted = false;
	
	for( ; i < URIPatternStr.length; i++ )
	{	if( URIPatternStr[i..$].startsWith("}{") )
			throw new Exception("Two parameters cannot follow consecutive in URI pattern!!!");
			
		if( URIPatternStr[i] == '{' )
		{	if( isNameStarted )
				throw new Exception("Bracket balance violation at: " ~ i.to!string );
			
			auto literal = URIPatternStr[lexemePos .. i];
			
			if( literal.length > 0 ) //Добавляем только не пустые литералы
				result ~= "l_" ~ literal;
			
			isNameStarted = true;
			lexemePos = i + 1;
		}
		else if( URIPatternStr[i] == '}' )
		{	//По закрытию скобочки добавляем имя параметра
			if( !isNameStarted )
				throw new Exception("Bracket balance violation at: " ~ i.to!string );
			
			auto paramName = URIPatternStr[lexemePos .. i];
			
			if( paramName.length > 0 )
				result ~= "p_" ~ paramName; //Добавляем имя параметра в список
			else
				throw new Exception("Name of the parameter in URI pattern cannot be empty!!!");
			
			isNameStarted = false;
			lexemePos = i + 1;
		}
	}
	
	if( isNameStarted ) //Проверка незакрытой скобки в конце шаблона
		throw new Exception("Bracket balance violation at: " ~ i.to!string );
	
	//Добавление литерала в конце шаблона
	if( lexemePos < URIPatternStr.length )
		result ~= "l_" ~ URIPatternStr[lexemePos .. $];
	
	return result;
}

bool pollLexemeSet(dstring[] lexemes, ref size_t literalCount, ref size_t paramCount)
{	literalCount = 0; paramCount = 0;
	byte prevLexType = -1; //Показывает тип пред. лексемы: 1=литерал, 0=парам, -1=неизвестно
	foreach( lexeme; lexemes )
	{	
		if( lexeme.startsWith("l_") )
		{	if( prevLexType == 1 )  //Если идут два литерала подряд
				return false; //=> ошибка
			literalCount++;
			prevLexType = 1;
		}
		else if( lexeme.startsWith("p_") )
		{	if( prevLexType == 0 ) //Если идут два параметра подряд
				return false; //=> ошибка
			paramCount++;
			prevLexType = 0;
		}
		else
			return false; //=> ошибка: неверный тип префикса лексемы
	}
	return true;
}

///Функция пытается разобрать адрес по шаблону, представленному массивом lexemes
///Возвращает структуру с результатами разбора
URIMatchingData parseURIByPattern( dstring URIStr, dstring[] lexemes )  //nothrow
{	
	//Количества литералов и параметров, которые нужно найти
	size_t unfoundLiteralCount = 0; 
	size_t unfoundParamCount = 0;
	
	//Опрос набора литералов на корректность и кол-ва лексем
	if( !pollLexemeSet(lexemes, unfoundLiteralCount, unfoundParamCount) )
		return URIMatchingData(null, false); //Некорректный набор литералов

	dstring[dstring] params; //Результирующий массив параметров
	
	size_t lexemeIndex = 0; //Номер текущей лексемы
	
	size_t paramValuePos = 0; //Позиция значения текущего параметра
	
	size_t i = 0; //Позиция окна анализа в строке
	
	//Функция добавления параметра
	//Значение параметра берётся с paramValuePos (вкл) до i (невключительно)
	//lexNum - номер лексемы, которая должна быть параметром
	//Возвращает true при успешном добавлении, иначе - false
	bool appendParam(size_t i, size_t lexNum)
	{	if( 
			lexNum < lexemes.length && 
			lexemes[lexNum].startsWith("p_") 
		)
		{	auto paramName = lexemes[lexNum][2..$];
			auto paramValue = URIStr[paramValuePos..i];
		
			if( paramName in params )
			{	if( paramValue != params[paramName] )
					return false;
			}
			else
			{	params[ paramName ] = paramValue;
				unfoundParamCount--;
			}
		}
		else
			return false;
		
		return true;
	}
	
	//Цикл просмотра строки и поиска литералов
	for( ; i < URIStr.length; i++ )
	{	if( lexemeIndex < lexemes.length )
		{	auto currLexeme = lexemes[lexemeIndex];
			if( currLexeme.startsWith("l_") && URIStr[i..$].startsWith( currLexeme[2..$] ) )
			{	
				if( lexemeIndex > 0 )
				{	if( !appendParam(i, lexemeIndex-1 ) )
						return URIMatchingData(null, false); //Ошибка при добавлении параметра
				}
				
				//Выставляем позицию после текущего литерала
				paramValuePos = i + currLexeme.length - 2; 
				
				lexemeIndex += 2;
				unfoundLiteralCount--;
				
				//На последнем литерале не станем менять i, чтобы проверить
				//совпадение конца URI
				if( lexemeIndex < lexemes.length )
					i = paramValuePos - 1;
				else
					break;
			}
		}
		else
			break;
	}
	
	if( lexemes.length > 0 )
	{	if( lexemes[$-1].startsWith("l_") )
		{	if( URIStr[i..$] != lexemes[$-1][2..$] )
				return URIMatchingData(null, false); //"Задняя часть" строки не соотв. последнему литералу
		}
		else if( lexemes[$-1].startsWith("p_") )
		{	if( !appendParam(URIStr.length, lexemes.length-1) )
				return URIMatchingData(null, false); //Ошибка при добавлении параметра
		}
	}
		
	//Проверяем количества ненайденных литералов и параметров
	if( unfoundLiteralCount == 0 && unfoundParamCount == 0 )
		return URIMatchingData(params,true); //Всё отлично!!!
	else
		return URIMatchingData(null, false); //Есть литералы, которые мы не нашли
}

URIMatchingData matchURI( 
	dstring URIStr, 
	dstring[] lexemes, 
	dstring[dstring] regExprs, 
	dstring[dstring] defaults 
)
{	auto parsingResult = parseURIByPattern(URIStr, lexemes);
	if( !parsingResult.isMatched )
		return parsingResult;
	
	auto params = parsingResult.params;
	
	//Задаём значения по-умолчанию для параметров
	foreach( paramName, value; defaults )
	{	if( params.get(paramName, null).length == 0 )
		{	params[paramName] = value;
		}
	}
	
	size_t matchedRegExprsCount = 0;
	//Проверка соответствия регулярным выражениям
	foreach( paramName, cond; regExprs )
	{	auto r = regex("^" ~ cond ~ "$", "g");
		if( paramName in params )
		{
			auto matchResult = matchFirst(params[paramName], r);
			if( !matchResult.empty )
			{	//Совпадение с шаблоном
				matchedRegExprsCount ++;
			}
			else
			{	//Несовпадение с шаблоном
				return URIMatchingData(null, false);
			}
			
		}
		else
		{	//Параметр с заданным именем не найден
			return URIMatchingData(null, false); 
		}
	}
	
	if( matchedRegExprsCount == regExprs.length )
		return URIMatchingData(params, true);
	else
		return URIMatchingData(null, false);
}

// void main()
// {	
// 	//На будущее
// // 	dstring URIPatternStr = `/dyn/pohod/by_date/(  {start_year}( |/{start_month} )(|/to/{end_year}(|/{end_month})))`;
// 	
// 	
// 	dstring plainURIPatternStr1 = `{fig}/dyn/pohod/by_date/{start_year}/{start_month}/to/{end_year}/{end_month}`;
// 	dstring URIExampleStr1 = `/dyn/pohod/by_date/2013/08/to/2014/06`;
// 	
// 	dstring plainURIPatternStr2 = `/dyn/pohod/by_date/{animal}/ololo_{name}/`;
// 	dstring URIExampleStr2 = `/dyn/pohod/by_date//ololo_vasya/`;
// 	
// 	dstring plainURIPatternStr3 = `/jsonrpc/{remainder}`;
// 	dstring URIExampleStr3 = `/dyn/edit_tourist`;
// 	
// 	dstring plainURIPatternStr4 = `{param}`;
// 	dstring URIExampleStr4 = `trololo`;
// 	
// 	auto pattern = parseURIPattern(plainURIPatternStr3);
// 	
// 	writeln( matchURI(URIExampleStr3, pattern, null, null) );
// 
// }