module webtank.templating.parser;
//apsychia, syncope, deliquium, pantamorphia- вариант названия

import std.stdio;
import std.conv;
import std.array: insertInPlace;
import std.array: back;
import std.string: strip;

enum   UTokenType
{	Unknown, Text, IdPre, IdSuf, Id, BodyPre, BodySuf, MatchOp};

immutable UTokenType[] StaticTokenTypes;

static this()
{	with (UTokenType)
		StaticTokenTypes = [IdPre, IdSuf, MatchOp, BodyPre, BodySuf];
}

struct UToken
{	dstring entityName;    //Имя "языковой" сущности
	UTokenType tokenType;  //Тип "языковой" единицы (токена)
	dstring text;           //Строковое представление токена
}

/** Исключения, не укладывающиеся в модель:
  *  - Текст
  *  - Неопознанные идентификаторы, отделяемые спец. символами
  */

struct UTokenBush
{
//protected:
	UToken[][] iTokens;
	size_t[] iPositions;
	//size_t iIndex=0;

//public:
	void putToken(UToken token, size_t strPos)
	{	bool IsTokenBeyondBounds = false;
		if (iPositions.length == 0) IsTokenBeyondBounds = true;
		else if (iPositions.back < strPos) IsTokenBeyondBounds =true;
		if (IsTokenBeyondBounds)
		{	iTokens ~= [token];
			iPositions ~= strPos;
			return ;
		}

		for (size_t i = (iPositions.length-1); i != size_t.max; --i)
		{	if (iPositions[i] == strPos)
			{	iTokens[i] ~= [token];
				return;
			}
			else if (iPositions[i] < strPos)
			{	iTokens.insertInPlace(i, [token]);
				iPositions.insertInPlace(i, strPos);
				write(i);  writeln("  aaa");
				return ;
			}
		}
	}

	//void appendBranch(UToken[] branch, size_t strPos)

	//Функция получения "ветви" по индексу
	/*UToken[] getBranch(size_t index)
	{	if (index<iTokens.length)
			return iTokens[index];
	}*/

	//Функция получения позиции в строке по индексу
	/*size_t getStrPos(size_t index)
	{	if (index<iPositions.length)
			return iPositions[index];
	}*/
}


//Структура описания сущности шаблонизатора
struct UEntity
{	bool hasId;      //Имеется идентификатор (ИД)
	bool hasBody;    //Имеется содержимое (Тело)
	//Набор лексем (строк), соответствующих некоторым простейшим
	//"единицам языка" (токенов)
	dstring[UTokenType] lexemeSet;
}

//Описание набора сущностей шаблонизатора по-умолчанию
///НЕ МЕНЯТЬ БЕЗ НЕОБХОДИМОСТИ!!!
//Создавайте свои "по образу и подобию" и передавайте в функцию анализа
immutable UEntity[dstring] DefaultEntitySet;

static this()
{	with (UTokenType) DefaultEntitySet=
	[	"blk"    : UEntity  (true, true, //Шаблонный блок
		[	IdPre   : "$",    IdSuf   : "$",
			MatchOp : ":",
			BodyPre : "{{",   BodySuf : "}}"
		]),
		"mark"   : UEntity  (true, false, //Метка
		[	IdPre   : "%",     IdSuf : "%"]),
		"var"    : UEntity  (true, true, //Переменная
		[	IdPre   : "$",      IdSuf : "$",
			MatchOp : "=",
			BodyPre : "\"",  BodySuf  : "\""
		]),
		"cmnt"   : UEntity  (false, true, //Коментарий
		[	BodyPre : "{**", BodySuf  : "*}"])
	];
}

immutable dstring TextEntityName = "txt";

/*bool checkEntitySet(UEntity[dstring] entitySet, ref dstring[] messages)
{

}*/

//enum dstring UnknownEntityName = "__666_unknown";


///Функция возвращает true, если символ является корректным символом
///идентификатора, и false - в противном случае. Допустимы символы
///латинского и русского алфавита и символ подчёркивания (_)
pure bool isIdSymbol(dchar ch)
{	if
	(	(  ('A'<=ch) && (ch<='Z')  ) ||
		(  ('a'<=ch) && (ch<='z')  ) ||
		(  ('А'<=ch) && (ch<='Я')  ) ||
		(  ('а'<=ch) && (ch<='я')  ) ||
		(  ('0'<=ch) && (ch<='9')  ) ||
		(ch=='_') || (ch=='ё')
	) return true;
	else return false;
}

///Функция возвращает true, если существует лексема и в ней есть символы,
///иначе возвращает false
pure bool lexemeExists
	(	UTokenType type,
		dstring entityName,
		const UEntity[dstring] entitySet = DefaultEntitySet
	)
{	if (entityName in entitySet) //Есть ли сущность
	{	auto Entity = entitySet[entityName];
		if (type in Entity.lexemeSet) //Есть ли лексема в наборе
			if (Entity.lexemeSet[type] !is null) //Лексема не null
				if (Entity.lexemeSet[type].length > 0u)  //Лексема не пустая строка
					return true;
	}
	return false; //Если что-то не выполнено, возвращаем false
}

///Находит, в какой сущности не заполнено какая-то лексема
///заданного типа из списка: IdPre, IdSuf, MatchOp, BodyPre, BodySuf
///из всех сущностей, где есть соответствующие части сущности
///(ИД, Тело или обе). Если найдено, где не заполнено, то возвращает
///false. Если лексема не из списка, соответствующей части сущности
///быть не должно или лексема заполнена, то возвращает true.
/*pure bool areAllLexemsOfTypeFilledIn
	(	UTokenType type,
		UEntity[dstring] entitySet = DefaultEntitySet,
	)
{	foreach (auto Entity; entitySet)
	{
	with (UTokenType)
	{	//Проверяем только заполненность префиксов, суффиксов ИД, Тела
		//и оператора сопоставления.
		if
			(	Entity.hasId &&
				(type == IdPre || type == IdSuf)
			)
		{	if ( !isLexemeFilledIn(type, EntName, entitySet) )
				return false;
		}
		if
			(	Entity.hasBody &&
				(type == BodyPre || type == BodySuf)
			)
		{	if ( !isLexemeFilledIn(type, EntName, entitySet) )
				return false;
		}
		if
			(	Entity.hasId &&
				Entity.hasBody &
				type == MatchOp
			)
		{	if ( !isLexemeFilledIn(type, EntName, entitySet) )
				return false;
		}
	} //with (UTokenType)
	}
	//Если никто не сказал, что что-то не заполнено,
	//то значит всё заполнено
	return true;
}*/
//Первый этап - лексический анализ. Или разбиение входной
//последовательности символов на токены.

/** В данной реализации предлагается разбивать входную
  * последовательность в структуру, которую я назвал "куст" (bush)
  * по аналогии с деревом (tree). У дерева число вложений
  * теоретически не ограничено, однако у моей структуры
  * их всего 2. Внутри она представлена двумерным массивом

  */

//struct UParserConfig
//{	bool option = true;
//}

///TODO: Подумать над названием этой части шаблонизатора
UTokenBush parseToTokenBush
	(	dstring src,  //Исходная строка для анализа
		const UEntity[dstring] entitySet = DefaultEntitySet //Описание набора сущностей
		//UParserConfig config = UParserConfig() //Прочие параметры шаблонизатора
	)
{	UTokenBush Result;

	struct UEntityState
	{	//Индексы "скобок": > 0, если открывающих больше 
		//< 0 если больше закрывающих
		bool idPreFound = false;
		bool bodyPreFound = false;
		size_t idStrPos = 0u;
		size_t TextPos = 0u;
		dstring idStr = null;
		
		//size_t lastTextPos = 0u;
		//dstring lastText = null;
	}
	

	//Создаём "состояния" сущностей
	UEntityState[dstring] EntityStates;
	bool[dstring] BodyXFixesAreEqual; //Показывает равны ли Префикс и Суффикс для Тела каждой сущности
	foreach (EntityName, Entity; entitySet)
	{	EntityStates[EntityName] = UEntityState(); //Создание "состояния"
		dstring Prefix = null;
		dstring Suffix = null;
		auto LexemeSet = &Entity.lexemeSet;
		with (UTokenType)
		{	if ( BodyPre in (*LexemeSet) )
				if ( (*LexemeSet)[BodyPre].length > 0u )
					Prefix = (*LexemeSet)[BodyPre];
			if ( BodySuf in (*LexemeSet) )
				if ( (*LexemeSet)[BodySuf].length > 0u )
					Suffix = (*LexemeSet)[BodySuf];
		}
		BodyXFixesAreEqual[EntityName] = (Prefix == Suffix);		
	}
		

	bool PrevWasIdSymbol = false;

	for (size_t i=0u; i<src.length; ++i)
	{	//Цикл проходит по всем именам сущностей кроме "неизвестной"
		foreach (EntityName, Entity; entitySet)
		{	//Ссылка на состояние для текущей сущности
			auto State = &EntityStates[EntityName] ;
			auto LexemeSet = &Entity.lexemeSet;
			bool IdPreFoundInThisStep = false;
			bool BodyPreFoundInThisStep = false;

			bool lexExists(UTokenType type)
			{	return lexemeExists (type, EntityName, entitySet);
			}
			
			

			//Функция обнаружения лексемы по типу и имени сущности
			bool isLexeme(UTokenType type)
			{	if ( lexemeExists(type, EntityName, entitySet) )
				{	auto Lexeme = &entitySet[EntityName].lexemeSet[type];
					size_t tokenEnd = i + (*Lexeme).length;
					if ( tokenEnd < src.length)
						return ( src[i..tokenEnd] == (*Lexeme) );
				}
				return false;
			}
			
			void putTokenWithText (UTokenType tokenType, dstring text, size_t strPos)
			{	/*if
				(	( strip(State.lastText).length > 0u ) &&
					( State.lastTextPos < src.length ) 
				) 
				{	Result.putToken
					(	UToken( TextEntityName, UTokenType.Text, State.lastText ), 
						State.lastTextPos
					);
					State.lastTextPos = size_t.max; //Сбрасываем текст
					State.lastText = null;
				}*/
				if (strPos < src.length)
				{	if (State.TextPos < strPos) 
					{	Result.putToken //Помещаем текст в "куст"
						(	UToken( /*TextEntityName*/ EntityName, UTokenType.Text, src[State.TextPos .. strPos].idup ), 
							State.TextPos 
						);
					}
					//Помещаем сам токен в "куст"
					if (text.length > 0u)
						Result.putToken
						(	UToken( EntityName, tokenType, text ), 
							strPos
						);
					
					if (tokenType == UTokenType.Id) 
					{	State.idStr = null;   State.idStrPos = size_t.max; //Сбрасываем ИД
					}
					//Передвигаем позицию текста
					State.TextPos = strPos + text.length;
				}
			}

			with (UTokenType)  //Покороче обращаемся к типам токенов
			{
			if (Entity.hasId) //У сущности есть ИД
			{
				if ( isIdSymbol(src[i]) ) //Текущий символ - символ ИД
				{	if (!PrevWasIdSymbol)
					{	if ( State.idPreFound || !lexExists(IdPre) )
							State.idStrPos = i; //Фиксируем позицию начала строки ИД
					}
				}
				else //Текущий - не символ ИД
				{	if (PrevWasIdSymbol) //Пред. символ - символ ИД
					{	if ( State.idPreFound || !lexExists(IdPre) )
						{	State.idStr = src[State.idStrPos .. i]; //Фиксируем строку ИД
							//if ( (TextPos < i) && (i < src.length) ) 
							//{	State.lastTextPos = TextPos; //Задаём предыдущий текст
							//	State.lastText = src[State.lastTextPos .. i]; 
							//}
						}

						if ( State.idPreFound && lexExists(IdPre) ) //Эта ветвь используется только для заполненного Префикса
						{	putTokenWithText ( Id, State.idStr, State.idStrPos );
						}
						
					}
				}

				if ( isLexeme(IdPre) ) //Префикс ИД
				{	if ( !State.idPreFound ) 
					{	putTokenWithText ( IdPre,  (*LexemeSet)[IdPre], i ); 
						State.idPreFound = true; //нашли префикс)
						IdPreFoundInThisStep = true;
					}
				}
				if ( isLexeme(IdSuf) ) 
				{	if ( State.idPreFound && !IdPreFoundInThisStep)  //Суффикс ИД
					{	putTokenWithText ( Id, State.idStr,  State.idStrPos );
						putTokenWithText ( IdSuf, (*LexemeSet)[IdSuf],  i );
						State.idPreFound = false;
					}
				}
			}

			//У сущности есть ИД и "туловище"
			if ( Entity.hasId && Entity.hasBody )
			{	if ( isLexeme(MatchOp) ) //Оператор сопоставления
				{	if (!lexExists(IdSuf))
					{	if (State.idPreFound)
							putTokenWithText ( Id, State.idStr,  State.idStrPos );
					}
					putTokenWithText ( MatchOp, (*LexemeSet)[MatchOp],  i );
					State.idPreFound = false; //Находим оператор сопоставления - любой поиск Ид прекращаем
				}
			}

			if (Entity.hasBody) //У сущности есть "туловище"
			{	if (BodyXFixesAreEqual[EntityName]) //Скобки тела одинаковы (иерархичность не предусмотрена)
				{	if ( isLexeme(BodyPre) ) //Префикс "туловища"
					{	if ( !State.bodyPreFound ) //Если Префикс ещё не найден (иерархичности нет)
						{	if ( !lexExists(IdSuf) && !lexExists(MatchOp) )
								putTokenWithText ( Id, State.idStr,  State.idStrPos ); //Добавление Ид
							putTokenWithText ( BodyPre, (*LexemeSet)[BodyPre],  i );
							State.bodyPreFound = true;
							BodyPreFoundInThisStep = true;
							State.idPreFound = false; //Находим префикс Тела - любой поиск Ид прекращаем
						}
					}
					if ( isLexeme(BodySuf) ) //Чисто формально - суффикс (хотя они равны)
					{	if ( State.bodyPreFound && !BodyPreFoundInThisStep ) //Теперь действительно чуффикс
						{	putTokenWithText ( BodySuf, (*LexemeSet)[BodySuf],  i );
							State.bodyPreFound = false;
							State.idPreFound = false; //На всякий пожарный //TODO: Возможно убрать?
						}
					}
				}
				else //Скобки Тела разные (возможны вложения)
				{ //Тут надо заморочиться с подсчётом открывающихся и закрывающихся ***фиксов
					if ( isLexeme(BodyPre) ) //Тут вроде префикс
					{	if ( !lexExists(IdSuf) && !lexExists(MatchOp) )
							putTokenWithText ( Id, State.idStr,  State.idStrPos ); //Добавление Ид
						putTokenWithText ( BodyPre, (*LexemeSet)[BodyPre],  i );
						State.idPreFound = false; //На всякий пожарный //TODO: Возможно убрать?
					}
					if ( isLexeme(BodySuf) ) //Тут похоже суффикс
					{	putTokenWithText ( BodySuf, (*LexemeSet)[BodySuf],  i );
						State.idPreFound = false; //На всякий пожарный //TODO: Возможно убрать?
					}
				}
			}
			} //with (UTokenType)
		}
		PrevWasIdSymbol=isIdSymbol(src[i]);
	}

	return Result;
}



int main()
{	write("Content-type: text/html; charset=\"utf-32\" \r\n\r\n");
	auto TokBush=parseToTokenBush(" %Отстой ^^^ % <a href=\"www.ya.ru\">Яндекс</a> $Дерьмо  ********   Рубидий ````$ sdfcsdfvdf $какашки$: {{ aaarrrrrgghhh!!!}}  %Гав%  $козявки$: {{ $мазявки$ : {{ кукареку  $кошки$ : {{ ***** }}  }} }}  ");

	for (size_t i=0; i<TokBush.iTokens.length; ++i)
	{	for (size_t j=0; j<TokBush.iTokens[i].length; ++j)
		{	auto Tok = &(TokBush.iTokens[i][j]);
			if (Tok.entityName == "blk")
			{	write("["); write(i); write(", "); write(j); write("]: ");
				write("("); write(TokBush.iPositions[i]); write("):  \"");
				write(Tok.text); write("\" ");
				write(Tok.entityName); write("  ");
				write(Tok.tokenType); writeln;
			}
		}

	}
	return 0;
}


