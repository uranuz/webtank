module webtank.net.http.handler;

import std.conv;

import webtank.net.http.context, webtank.net.http.http;

///Код результата обработки запроса
enum HTTPHandlingResult {
	mismatched, //Обработчик не соответствует данному запросу
	unhandled,  //Обработчик не смог обработать данный запрос
	handled     //Обработчик успешно обработал запрос
	/*, redirected*/  //Зарезервировано: обработчик перенаправил запрос на другой узел
}

/// Интерфейс обработчика HTTP-запросов приложения
interface IHTTPHandler
{
	/// Метод обработки запроса. Возвращает true, если запрос обработан.
	/// Возвращает false, если запрос не соответствует обработчику
	/// В случае ошибки кидает исключение
	HTTPHandlingResult processRequest(HTTPContext context);
}

/// Интерфейс составного обработчика HTTP-запросов
interface ICompositeHTTPHandler: IHTTPHandler
{
	/// Добавление обработчика запросов
	/// Должен возвращать this в качестве результата
	ICompositeHTTPHandler addHandler(IHTTPHandler handler);
}

///Типы обработчиков, используемых при обработке HTTP-запросов
///Соглашения:
///		sender - отправитель события
///		context - контекст обрабатываемого запроса

///Тип обработчика: ошибка при обработке HTTP-запроса
///		error - перехваченное исключение, которое нужно обработать
alias bool delegate(Throwable error, HTTPContext context) ErrorHandler;

///Тип обработчика: начало опроса обработчика HTTP-запроса
alias void delegate(HTTPContext context) PrePollHandler;

///Тип обработчика: начало опроса обработчика HTTP-запроса
///		isMatched - имеет значение true, если запрос соответствует данному обработчику, т.е
///			он по формальным критериям определил, что хочет/может его обработать. Иначе - false
alias void delegate(HTTPContext context, bool isMatched) PostPollHandler;

// ///Тип обработчика: начало обработки HTTP-запроса
// alias void delegate(HTTPContext context) PreProcessHandler;

///Тип обработчика: завершение обработки HTTP-запроса
///		result - результат обработки запроса обработчиком
alias void delegate(HTTPContext context, HTTPHandlingResult result) PostProcessHandler;

///Базовый класс набора обработчиков HTTP-запросов
mixin template EventBasedHTTPHandlerImpl()
{
	import webtank.net.http.context;
	import webtank.net.http.http;
	import webtank.common.event;

	///События, возникающие при обработке запроса
	@property {
		///Событие: ошибка при обработке HTTP-запроса
		ref ErrorEvent!(ErrorHandler, StopHandlingValue!(true)) onError() {
			return _errorEvent;
		}
		
		///Событие: начало опроса обработчика HTTP-запроса
		ref Event!(PrePollHandler) onPrePoll() {
			return _prePollEvent;
		}

		///Событие: начало опроса обработчика HTTP-запроса
		ref Event!(PostPollHandler) onPostPoll() {
			return _postPollEvent;
		}
		
// 		///Событие: начало обработки HTTP-запроса
// 		ref Event!(PreProcessHandler) onPreProcess()
// 		{	return _preProcessEvent; }
		
		///Событие: завершение обработки HTTP-запроса
		ref Event!(PostProcessHandler) onPostProcess() {
			return _postProcessEvent;
		}
	}
	
	///Реализация обработчика HTTP-запроса по-умолчанию.
	///Без отсутствия явной необходимости не переопределять,
	///а использовать переопределение customProcessRequest
	override HTTPHandlingResult processRequest(HTTPContext context)
	{
		context._setCurrentHandler(this);
		scope(exit) context._unsetCurrentHandler(this);
		
		try
		{
			onPrePoll.fire(context);

			HTTPHandlingResult result = this.customProcessRequest(context);
			onPostProcess.fire(context, result);

			if( result == HTTPHandlingResult.unhandled ) {
				throw new HTTPException("Request hasn't been handled by matched HTTP handler", 404);
			}

			return result;
		}
		catch( Throwable error )
		{
			if( onError.fire(error, context) )
				return HTTPHandlingResult.handled; // Ошибка обработана -> запрос обработан
			else
				throw error; // Ни один обработчик не смог обработать ошибку
		}
	}
	
	///Переопределяемый пользователем метод для обработки запроса
	//abstract HTTPHandlingResult customProcessRequest(HTTPContext context);
	
protected:
	ErrorEvent!(ErrorHandler, StopHandlingValue!(true)) _errorEvent;
	Event!(PrePollHandler) _prePollEvent;
	Event!(PostPollHandler) _postPollEvent;
// 	Event!(PreProcessHandler) _preProcessEvent;
	Event!(PostProcessHandler) _postProcessEvent;
}

mixin template BaseCompositeHTTPHandlerImpl()
{
	protected IHTTPHandler[] _handlers;

	/// Добавление обработчика HTTP-запроса
	override ICompositeHTTPHandler addHandler(IHTTPHandler handler)
	{
		_handlers ~= handler;
		return this;
	}
}

class HTTPRouter: ICompositeHTTPHandler
{
	mixin EventBasedHTTPHandlerImpl;
	mixin BaseCompositeHTTPHandlerImpl;

	HTTPHandlingResult customProcessRequest(HTTPContext context)
	{
		// TODO: Проверить, что имеем достаточно корректный HTTP-запрос
		onPostPoll.fire(context, true);
		foreach( hdl; _handlers )
		{
			if( hdl.processRequest(context) == HTTPHandlingResult.handled ) {
				return HTTPHandlingResult.handled;
			}
		}

		return HTTPHandlingResult.unhandled;
	}
}


import webtank.net.uri_pattern;

/// Обработчик для конкретного маршрута к странице сайта
class URIPageRoute: IHTTPHandler
{
protected:
	URIPattern _uriPattern;
	PageHandler _handler;

public:
	alias PageHandler = void delegate(HTTPContext);

	this(PageHandler handler, string uriPatternStr) {
		_handler = handler;
		_uriPattern = new URIPattern(uriPatternStr);
	}
	
	this(PageHandler handler, URIPattern uriPattern) {
		_handler = handler;
		_uriPattern = uriPattern;
	}

	override HTTPHandlingResult processRequest(HTTPContext context)
	{
		auto pageURIData = _uriPattern.match(context.request.uri.path);
		if( pageURIData.isMatched )
		{
			context.request.requestURIMatch = pageURIData;
			_handler(context);
			return HTTPHandlingResult.handled; // Запрос обработан
		}
		return HTTPHandlingResult.mismatched;
	}
}

/// Маршрутизатор запросов к страницам сайта по URI
class URIPageRouter: ICompositeHTTPHandler
{
	mixin EventBasedHTTPHandlerImpl;
	mixin BaseCompositeHTTPHandlerImpl;

	this(string uriPatternStr) {
		_uriPattern = new URIPattern(uriPatternStr);
	}
	
	this(URIPattern uriPattern) {
		_uriPattern = uriPattern;
	}

	HTTPHandlingResult customProcessRequest( HTTPContext context )
	{
		auto uriData = _uriPattern.match(context.request.uri.path);
		if( uriData.isMatched )
			context.request.requestURIMatch = uriData;

		onPostPoll.fire(context, uriData.isMatched);

		if( !uriData.isMatched )
			return HTTPHandlingResult.mismatched;

		// Перебор маршрутов к страницам
		foreach( hdl; _handlers )
		{
			if( hdl.processRequest(context) == HTTPHandlingResult.handled ) {
				return HTTPHandlingResult.handled; // Запрос обработан
			}
		}

		return HTTPHandlingResult.mismatched; // Обработчик для запроса не найден
	}
protected:
	URIPattern _uriPattern;
}

import std.functional: toDelegate;
import std.traits: ReturnType, Parameters;
template join(alias Method)
	if(
		is(ReturnType!(Method) == void) && Parameters!(Method).length == 1 && is(Parameters!(Method)[0] : HTTPContext)
	)
{
	auto join(ICompositeHTTPHandler parentHdl, string uriPatternStr)
	{
		parentHdl.addHandler(
			new URIPageRoute(cast(void delegate(HTTPContext)) toDelegate(&Method), uriPatternStr)
		);
		return parentHdl;
	}

	auto join(ICompositeHTTPHandler parentHdl, URIPattern uriPattern)
	{
		parentHdl.addHandler(
			new URIPageRoute(cast(void delegate(HTTPContext)) toDelegate(&Method), uriPattern)
		);
		return parentHdl;
	}
}

/// Обработчик метода, принимающий данные в формате веб-формы,
/// и возвращающий в виде как JSON-RPC (ответ - поле result, ошибка - поле error)
class WebFormAPIPageRoute: IHTTPHandler
{
	import std.json: JSONValue;
protected:
	URIPattern _uriPattern;
	PageHandler _handler;

public:
	alias PageHandler = JSONValue delegate(HTTPContext);

	this(PageHandler handler, string uriPatternStr) {
		_handler = handler;
		_uriPattern = new URIPattern(uriPatternStr);
	}
	
	this(PageHandler handler, URIPattern uriPattern) {
		_handler = handler;
		_uriPattern = uriPattern;
	}

	override HTTPHandlingResult processRequest(HTTPContext context)
	{
		import std.json: toJSON, JSONOptions;
		auto pageURIData = _uriPattern.match(context.request.uri.path);
		if( pageURIData.isMatched )
		{
			context.request.requestURIMatch = pageURIData;
			JSONValue jResponse = [
				"jsonrpc": JSONValue("2.0"),
				"id": JSONValue()
			];
			try
			{
				jResponse["result"] = _handler(context);
			}
			catch(Exception ex)
			{
				jResponse["error"] = [
					"code": JSONValue(1), // Пока не знаю откуда мне брать код ошибки... Пусть будет 1
					"message": JSONValue(ex.msg),
					"data": JSONValue([
						"file": JSONValue(ex.file),
						"line": JSONValue(ex.line)
					])
				];
				debug {
					import std.array: appender;
					auto backTrace = appender!(string[])();
					foreach( inf; ex.info ) backTrace ~= inf.idup;
					jResponse["error"]["data"]["backtrace"] = JSONValue(backTrace.data);
				}
				//onError.fire(ex, context); // Just notify error handler about error for now
			}
			context.response ~= toJSON(jResponse, false, JSONOptions.specialFloatLiterals);

			return HTTPHandlingResult.handled; // Запрос обработан
		}
		return HTTPHandlingResult.mismatched;
	}
}

import std.traits: isSomeFunction;
template joinWebFormAPI(alias Method)
	if( isSomeFunction!(Method) )
{
	auto joinWebFormAPI(ICompositeHTTPHandler parentHdl, string uriPatternStr)
	{
		parentHdl.addHandler(
			new WebFormAPIPageRoute(toDelegate(&callWebFormAPIMethod!Method), uriPatternStr)
		);
		return parentHdl;
	}

	auto joinWebFormAPI(ICompositeHTTPHandler parentHdl, URIPattern uriPattern)
	{
		parentHdl.addHandler(
			new WebFormAPIPageRoute(toDelegate(&callWebFormAPIMethod!Method), uriPattern)
		);
		return parentHdl;
	}
}

import std.json: JSONValue;
JSONValue callWebFormAPIMethod(alias Method)(HTTPContext ctx)
{
	import std.traits: Parameters, ParameterIdentifierTuple, ParameterDefaults;
	import std.typecons: Tuple;
	import std.exception: enforce;
	alias ParamTypes = Parameters!(Method);
	alias ResultType = ReturnType!(Method);
	alias ParamNames = ParameterIdentifierTuple!(Method);
	alias MethDefaults = ParameterDefaults!(Method);
	import webtank.net.deserialize_web_form: formDataToStruct;
	import webtank.common.std_json.to: toStdJSON;

	Tuple!(ParamTypes) argTuple;
	foreach( i, paramName; ParamNames )
	{
		alias ParamType = ParamTypes[i];
		static if( is(ParamType : HTTPContext) )
		{
			auto typedContext = cast(ParamType) ctx;
			enforce(
				typedContext,
				`Error in attempt to convert parameter "` ~ ParamNames[i] ~ `" to type "` ~ ParamType.stringof ~ `". Context reference is null!`
			);
			argTuple[i] = typedContext; //Передаём контекст при необходимости
		}
		else static if( is( ParamType == struct ) )
		{
			formDataToStruct(ctx.request.form, argTuple[i]); // Ищем простые поля формы типа: "familyName"
			formDataToStruct(ctx.request.form, argTuple[i], paramName); // Ищем вложенные поля типа: "filter.familyName"
		}
		else
		{
			import webtank.common.conv: conv;
			argTuple[i] = ctx.request.form.get(paramName, null).conv!(ParamType);
		}
	}

	JSONValue result;
	static if( is( ResultType == void ) ) {
		Method(argTuple.expand);
	} else {
		result = toStdJSON( Method(argTuple.expand) );
	}
	return result;
}