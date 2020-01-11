module webtank.net.http.handler.mixins;

///Базовый класс набора обработчиков HTTP-запросов
mixin template EventBasedHTTPHandlerImpl()
{
	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.http;
	import webtank.common.event: Event, ErrorEvent, StopHandlingValue;
	import webtank.net.http.handler.iface;

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
			if( onError.fire(error, context) ) {
				return HTTPHandlingResult.handled; // Ошибка обработана -> запрос обработан
			}
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
	Event!(PostProcessHandler) _postProcessEvent;
}

mixin template BaseCompositeHTTPHandlerImpl()
{
	import webtank.net.http.handler.iface;
	protected IHTTPHandler[] _handlers;

	/// Добавление обработчика HTTP-запроса
	override ICompositeHTTPHandler addHandler(IHTTPHandler handler)
	{
		_handlers ~= handler;
		return this;
	}

	import std.json: JSONValue;

	JSONValue handlersToStdJSON()
	{
		import std.algorithm: map;
		import std.array: array;
		return JSONValue(_handlers.map!( (it) => it.toStdJSON() ).array);
	}
}