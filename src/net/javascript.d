module webtank.net.javascript;

import std.string, std.stdio;
//Модуль для управления программным кодом на JavaScript

enum CommentState { none, inline, multiline };

auto parseJavaScriptPackage(string src)
{	string[string] result;

	long bracketBalance = 0;
	enum QuoteState { none, singleQuote, dupQuote };
	
	auto commentState = CommentState.none; //Как закомментирован код
	auto quoteState = QuoteState.none;  //Как "закавычен" текст
	
	auto colonPos = size_t.max;
	auto commaPos = size_t.max;
	auto equalPos = size_t.max;
	size_t packageNameStartPos = 0;
	
	string packageName;
	
	bool isActiveCode() //true, если код не в кавычках и не в комментариях
	{	return ( commentState == CommentState.none && quoteState == QuoteState.none ); }
	
	for( size_t i = 0; i < src.length; i++ )
	{	void appendProperty()
		{	if( colonPos + 1 < src.length && commaPos < colonPos )
			{	import std.string;
				string propertyName = packageName ~ "."
					~ cleanUpJavaScript( src[ commaPos+1 .. colonPos ] );
				result[ propertyName ] = std.string.strip( src[ colonPos+1 .. i ] );
			}
		}
		
		if( src[i] == '=' && bracketBalance == 0 )
		{	if( packageNameStartPos < src.length )
				packageName = cleanUpJavaScript( src[ packageNameStartPos..i ] );
		}
		if( src[i] == ';' && bracketBalance == 0 )
		{	packageNameStartPos = i+1;
			
		}
		
		if( ( i+2 < src.length && src[i..i+2] == "\r\n" ) || src[i] == '\n' )
		{	if( commentState == CommentState.inline && quoteState == QuoteState.none )
				commentState = CommentState.none; //Закончился однострочный комментарий
		}
		else if( src[i] == '\'' )
		{	if( quoteState == QuoteState.singleQuote )
				quoteState = QuoteState.none;
			else if( quoteState == QuoteState.none )
				quoteState = QuoteState.singleQuote;
		}
		else if( src[i] == '\"' )
		{	if( quoteState == QuoteState.dupQuote )
				quoteState = QuoteState.none;
			else if( quoteState == QuoteState.none )
				quoteState = QuoteState.dupQuote;
		}
		else if( i+2 < src.length && quoteState == QuoteState.none )
		{	if( src[i..i+2] == "//" )
			{	if( commentState == CommentState.none )
					commentState = CommentState.inline; //Начался однострочный комментарий
			}
			else if( src[i..i+2] == "/*" )
			{	if( commentState == CommentState.none )
					commentState = CommentState.multiline; //Начался однострочный комментарий
			}
			else if( src[i..i+2] == "*/" )
			{	if( commentState == CommentState.multiline )
					commentState = CommentState.none; //Закончился многострочный комментарий
			}
		}
		
		if( isActiveCode() )
		{	if( src[i] == ':' && bracketBalance == 1 )
				colonPos = i;
			else if( src[i] == ',' )
			{	if( bracketBalance == 1 )
				{	appendProperty();
					commaPos = i;
				}
			}
			else if( src[i] == '{' )
			{	if( bracketBalance == 0 )
					commaPos = i;
				bracketBalance++;
			}
			else if( src[i] == '}' )
			{	if( bracketBalance == 1 )
					appendProperty();
				bracketBalance--;
			}
		}
		
	}
	return result;
}

string cleanUpJavaScript(string src) {
	string result;
	auto commentState = CommentState.none;
	size_t startPos = 0;
	
	size_t i = 0;
	for( ; i < src.length; i++ )
	{	if( commentState == CommentState.inline )
		{	if( ( i+2 < src.length && src[i..i+2] == "\r\n" ) || src[i] == '\n' )
			{	startPos = i + ( src[i] == '\n' ? 1 : 2 );
				if( src[i] != '\n' ) 
					i++;
				commentState = CommentState.none; //Закончился однострочный комментарий
			}
		}
		else if( commentState == CommentState.none )
		{	if( src[i] == '\t' )
			{	result ~= src[ startPos .. i ];
				startPos = i+1;
			}
		}
		
		if( i+2 < src.length )
		{	if( src[i..i+2] == "//" )
			{	if( commentState == CommentState.none )
				{	result ~= src[ startPos .. i ];
					i++;
					commentState = CommentState.inline; //Начался однострочный комментарий
				}
			}
			else if( src[i..i+2] == "/*" )
			{	if( commentState == CommentState.none )
				{	result ~= src[ startPos .. i ];
					i++;
					commentState = CommentState.multiline; //Начался однострочный комментарий
				}
			}
			else if( src[i..i+2] == "*/" )
			{	if( commentState == CommentState.multiline )
				{	startPos = i+2;
					i++;
					commentState = CommentState.none;
				}
			}
		}
	}
	if( commentState == CommentState.none )
		result ~= src[ startPos..$ ];
	import std.string;
	return std.string.strip( result );
}

// void main()
// {	string someString = 
// `		package = {
// 			vasya: goblin,
// 			petya: 1, //Проклятый, гоблин : огого
// 			doSmth: function( {
// 				trololo: aaa;
// 			},
// 			aaa: "igogo",
// 		};
// `;
// 	import std.stdio;
// 	
// 	writeln( parseJavaScriptPackage(someString) );
// 	writeln( cleanUpJavaScript("		//ogorofo\n 	petya /*dfgdfgfd*/") );
// }