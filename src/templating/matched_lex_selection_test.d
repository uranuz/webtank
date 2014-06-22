module webtank.test.matched_lex_selection_test;

struct Lexeme
{	dstring name;
	dstring value;
}

enum dstring[] lexValues = 
[	":=", "{{", "}}", "{{?", "}}"
];

enum dstring[] lexNames = 
[	"matchOp", "markPre", "markSuf", "varPre", "varSuf"];




import std.algorithm;
import std.stdio;

void main()
{	//Пытаемся создать сортированный список по убыванию длины значения лексемы
	//Лексемы должны удовлетворять строке поиска
	dstring parsedStr = ":=dfgdf";
	Lexeme[] selLexemes;
	size_t lexCount = lexNames.length;
	writeln(lexCount);
	
	bool varPreFound = true;
	bool varMatchOpFound = false;
	bool markPreFound = false;
	
	alias bool delegate() CheckFuncT;
	CheckFuncT[] checkFuncs;
	checkFuncs.length = lexCount;
	checkFuncs[0] = (){	return varPreFound; };
	checkFuncs[2] = (){	return markPreFound; };
	checkFuncs[4] = (){	return (varPreFound && varMatchOpFound); };
	
	alias void delegate() CommitFuncT;
	CommitFuncT[] commitFuncs;
	commitFuncs.length = lexCount;
	commitFuncs[0] = (){	varMatchOpFound = true; };
	commitFuncs[1] = (){	markPreFound = true; };
	commitFuncs[2] = (){	markPreFound = false; };
	commitFuncs[3] = (){	varPreFound = true; };
	commitFuncs[4] = (){
		varPreFound = false;
		varMatchOpFound = false;
	};
	
	for( size_t i = 0; i < lexCount; ++i )
	{	auto curLexName = lexNames[i];
		auto curLexValue = lexValues[i];
		if( (i + curLexValue.length) < parsedStr.length )
		{	if( parsedStr[0 .. curLexValue.length] == curLexValue )
			{	//Если нашли, то добавляем в сортированный список новый элемент
				bool checked = ( checkFuncs[i] is null ) ? true : checkFuncs[i]();
				if( checked )
				{	selLexemes ~= Lexeme(curLexName, curLexValue);
					
				}
			}
		}
		
		
	}
	
	writeln(selLexemes);
	writeln(selLexemes);
	auto sortedLexemes = sort!("a.value.length > b.value.length")(selLexemes);
	writeln(sortedLexemes);
}
