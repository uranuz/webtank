module webtank.net.http.handler;

import std.conv;

import webtank.net.http.context, webtank.common.event, webtank.net.http.http;

///Код результата обработки запроса
enum HTTPHandlingResult
{	mismatched, //Обработчик не соответствует данному запросу
	unhandled,  //Обработчик не смог обработать данный запрос
	handled     //Обработчик успешно обработал запрос
	/*, redirected*/  //Зарезервировано: обработчик перенаправил запрос на другой узел
};

///Интерфейс обработчика HTTP-запросов приложения
interface IHTTPHandler
{	///Метод обработки запроса. Возвращает true, если запрос обработан.
	///Возвращает false, если запрос не соответствует обработчику
	///В случае ошибки кидает исключение
	HTTPHandlingResult processRequest( HTTPContext context );
}

///Типы обработчиков, используемых при обработке HTTP-запросов
///Соглашения:
///		sender - отправитель события
///		context - контекст обрабатываемого запроса

///Тип обработчика: ошибка при обработке HTTP-запроса
///		error - перехваченное исключение, которое нужно обработать
alias bool delegate(Throwable error, HTTPContext context) ErrorHandler;

///Тип обработчика: начало опроса обработчика HTTP-запроса
alias void delegate(HTTPContext context)  PrePollHandler;

///Тип обработчика: начало опроса обработчика HTTP-запроса
///		isMatched - имеет значение true, если запрос соответствует данному обработчику, т.е
///			он по формальным критериям определил, что хочет/может его обработать. Иначе - false
alias void delegate(HTTPContext context, bool isMatched)  PostPollHandler;

// ///Тип обработчика: начало обработки HTTP-запроса
// alias void delegate(HTTPContext context) PreProcessHandler;

///Тип обработчика: завершение обработки HTTP-запроса
///		result - результат обработки запроса обработчиком
alias void delegate(HTTPContext context, HTTPHandlingResult result) PostProcessHandler;

///Базовый класс набора обработчиков HTTP-запросов
class EventBasedHTTPHandler: IHTTPHandler
{
	///События, возникающие при обработке запроса
	@property {
		///Событие: ошибка при обработке HTTP-запроса
		ref ErrorEvent!(ErrorHandler, StopHandlingValue!(true) ) onError()
		{	return _errorEvent; }
		
		///Событие: начало опроса обработчика HTTP-запроса
		ref Event!(PrePollHandler) onPrePoll()
		{	return _prePollEvent; }

		///Событие: начало опроса обработчика HTTP-запроса
		ref Event!(PostPollHandler) onPostPoll()
		{	return _postPollEvent; }
		
// 		///Событие: начало обработки HTTP-запроса
// 		ref Event!(PreProcessHandler) onPreProcess()
// 		{	return _preProcessEvent; }
		
		///Событие: завершение обработки HTTP-запроса
		ref Event!(PostProcessHandler) onPostProcess()
		{	return _postProcessEvent; }
	}
	
	///Реализация обработчика HTTP-запроса по-умолчанию.
	///Без отсутствия явной необходимости не переопределять,
	///а использовать переопределение customProcessRequest
	HTTPHandlingResult processRequest( HTTPContext context )
	{	context._setCurrentHandler(this);
		scope(exit) context._unsetCurrentHandler(this);
		
		try {
			onPrePoll.fire(context);

			HTTPHandlingResult result = customProcessRequest(context);
			onPostProcess.fire(context, result);

			if( result == HTTPHandlingResult.unhandled )
				throw new HTTPException("Request hasn't been handled by matched HTTP handler", 404);
			
			return result;
		}
		catch( Throwable error )
		{	if( onError.fire(error, context) )
				return HTTPHandlingResult.handled; //Ошибка обработана -> запрос обработан
			else
				throw error; //Ни один обработчик не смог обработать ошибку
		}
		
		return HTTPHandlingResult.unhandled; //Запрос не обработан
	}
	
	///Переопределяемый пользователем метод для обработки запроса
	abstract HTTPHandlingResult customProcessRequest( HTTPContext context );
	
protected:
	ErrorEvent!( ErrorHandler, StopHandlingValue!(true) ) _errorEvent;
	Event!(PrePollHandler) _prePollEvent;
	Event!(PostPollHandler) _postPollEvent;
// 	Event!(PreProcessHandler) _preProcessEvent;
	Event!(PostProcessHandler) _postProcessEvent;
}

class HTTPRouter: EventBasedHTTPHandler
{	
	override HTTPHandlingResult customProcessRequest( HTTPContext context )
	{	//TODO: Проверить, что имеем достаточно корректный HTTP-запрос
		onPostPoll.fire(context, true);
		foreach( hdl; _handlers )
		{	if( hdl.processRequest(context) == HTTPHandlingResult.handled  )
				return HTTPHandlingResult.handled;
		}
		
		return HTTPHandlingResult.unhandled;
	}
	
	///Метод присоединения обработчика HTTP-запроса
	HTTPRouter join(IHTTPHandler handler)
	{	_handlers ~= handler;
		return this;
	}
	
	///Метод присоединения массива обработчиков HTTP-запросов к набору
	HTTPRouter join(IHTTPHandler[] handlers)
	{	_handlers ~= handlers;
		return this;
	}
	
protected:
	IHTTPHandler[] _handlers;
}


import webtank.net.uri_pattern;

///Маршрутизатор запросов к страницам сайта по URI
class URIPageRouter: EventBasedHTTPHandler
{	
	this( string URIPatternStr, string[string] regExprs, string[string] defaults )
	{	_uriPattern = new URIPattern(URIPatternStr, regExprs, defaults);
	}
	
	this( string URIPatternStr, string[string] defaults = null )
	{	this(URIPatternStr, null, defaults);
	}
	
	alias void delegate(HTTPContext) PageHandler;
	
	override HTTPHandlingResult customProcessRequest( HTTPContext context )
	{	auto uriData = _uriPattern.match(context.request.uri.path);

		onPostPoll.fire(context, uriData.isMatched);
		
		if( !uriData.isMatched )
			return HTTPHandlingResult.mismatched;
		
		//Перебор маршрутов к страницам
		foreach( ref route; _pageRoutes )
		{	auto pageURIData = route.pattern.match(context.request.uri.path);

			if( pageURIData.isMatched )
			{	route.handler(context);
				return HTTPHandlingResult.handled; //Запрос обработан
			}
		}
		
		return HTTPHandlingResult.unhandled; //Запрос не обработан этим узлом
	}

	struct PageRoute
	{	URIPattern pattern;
		PageHandler handler;
	}
	
	template join(alias Method)
	{	import std.functional;
		URIPageRouter join(string URIPatternStr, string[string] regExprs, string[string] defaults)
		{	auto uriPattern = new URIPattern(URIPatternStr, regExprs, defaults);
			_pageRoutes ~= PageRoute( uriPattern, toDelegate( &Method ) );
			return this;
		}
		
		URIPageRouter join(string URIPatternStr, string[string] defaults = null)
		{	return this.join!(Method)( URIPatternStr, null, defaults );
		}
	}
	
protected:
	PageRoute[] _pageRoutes;
	URIPattern _uriPattern;
}