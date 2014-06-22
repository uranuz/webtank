module webtank.common.event;

/++
$(LOCALE_EN_US
	Enumerable representing set of options for configuring event object
)

$(LOCALE_RU_RU
	Перечислимый тип представляющий набор опций для настройки события
)
+/
enum EventOption
{
	/++
	$(LOCALE_EN_US Synchronized event object access)
	$(LOCALE_RU_RU Синхронизированный лоступ к объекту события)
	+/
	synchronized_,

	/++
	$(LOCALE_EN_US Allow subscribe to event with the same callback multiple times)
	$(LOCALE_RU_RU Разрешение подписываться на событие одним обработчиком несколько раз)
	+/
	allowDuplicateHandlers,

	/++
	$(LOCALE_EN_US Stop propagatating event after getting some return value from handler)
	$(LOCALE_RU_RU Остановка запуска обработчиков после получение некоторого возвращаемого значения)
	+/
	stopOnValue,

	/++
	$(LOCALE_EN_US Service flag)
	$(LOCALE_RU_RU Служебный флаг)
	+/
	stopHandlingValue,
};

template OptionPair(alias first, alias second)
{	enum type = first;
	enum value = second;
}

/++
$(LOCALE_EN_US
	Option that signals whether to sunchronize access to ErrorEvent object.
	If option parameter is true then it's synchronized
)

$(LOCALE_RU_RU
	Опция события определяющая необходимость синхронизированного доступа.
	Если параметр опции есть true, то доступ синхронизируется
)
+/
template Synchronized(bool value)
{	alias OptionPair!(EventOption.synchronized_, value) Synchronized;
}

/++
$(LOCALE_EN_US
	Option that signals whether duplicate handlers are allowed.
	If option parameter is set to true then duplicates enabled.
	If duplicates are not allowed but programme is trying to subscribe
	to event with the same handler multiple times then exception is thrown
)

$(LOCALE_RU_RU
	Опция опция определяет разрешены ли дублирующие обработчики событий.
	Если параметр опции установлен в true, то дупликаты разрешены.
	Если дупликаты не разрешены, однако программа пытается подписаться
	на событие одним и тем же обработчиком несколько раз, то будет
	брошено исключение
)
+/
template AllowDuplicateHandlers(bool value)
{	alias OptionPair!(EventOption.allowDuplicateHandlers, value) AllowDuplicateHandlers;
}

/++
$(LOCALE_EN_US
	Option defines return value that signals handling interrupt.
	Interrupting doesn't affect priorite handers
)

$(LOCALE_RU_RU
	Опция определяет возвращаемое значение, которое сигнализирует о прерывании
	обработки события. При этом оставшиеся в списке подписки обработчики не будут выполнены.
	Данное прерывание не распространяется на приоритетные обработчики, которые
	будут запущены в любом случае
)
+/
template StopHandlingValue(alias value)
{	alias OptionPair!(EventOption.stopHandlingValue, value) StopHandlingValue;
}

/++
$(LOCALE_EN_US
	Service template for getting value for event option
)

$(LOCALE_RU_RU
	Служебный шаблон для получения значения для опции события
)
+/
template GetEventOption(EventOption optType, Opts...)
{	static if( Opts.length > 0 )
	{	static if( is( typeof(Opts[0].type) == EventOption ) )
		{	static if( Opts[0].type == EventOption.stopHandlingValue && optType == EventOption.stopOnValue )
				enum bool GetEventOption = true;
			else static if( Opts[0].type == optType )
				enum GetEventOption = Opts[0].value;
			else
				enum GetEventOption = GetEventOption!(optType, Opts[1..$]);
		}
	 	else
			enum GetEventOption = GetEventOption!(optType, Opts[1..$]);
	}
 	else
	{	static if( optType == EventOption.synchronized_ )
			enum bool GetEventOption = false;
	 	else static if( optType == EventOption.allowDuplicateHandlers )
			enum bool GetEventOption = true;
		else static if( optType == EventOption.stopOnValue )
			enum bool GetEventOption = false;
	 	else
			static assert( 0, "Can't get default value for ErrorEvent option");
	}
}

import std.traits : isCallable, isDelegate;

/++
$(LOCALE_EN_US
	Struct representing event object
)

$(LOCALE_RU_RU
	Структура, представляющая событие
)
+/
struct Event(Opts...)
	if (Opts.length >= 1 && Opts.length <= 3 && isCallable!(Opts[0]))
{
	import std.functional : toDelegate;
	import std.traits : ParameterTypeTuple;

	static if (Opts.length >= 2)
	{
		static if (!is(typeof(Opts[1]) == bool))
			static assert(0, "Expected a bool representing whether to allow duplicates!");
		public enum allowDuplicates = Opts[1];
	}
	else
		public enum allowDuplicates = false;

	static if (Opts.length >= 3)
	{
		static if( !is(typeof(Opts[2]) == bool))
			static assert(0, "Expected a bool representing whether to synchronize access!");
		public enum isSynchronized = Opts[2];
	}
	else
		public enum isSynchronized = false;

	static if (isDelegate!(Opts[0]) || isFunction!(Opts[0]))
		public alias DelegateType = Opts[0];
	else
		public alias DelegateType = typeof(&Opts[0]);

	private DelegateType[] subscribedCallbacks;
	
	static if (isSynchronized)
		private Object lock = new Object();
	private R MaybeSynchronous(R)(R delegate() d)
	{
		static if (isSynchronized)
		{
			synchronized (lock)
			{
				return d();
			}
		}
		else
			return d();
	}

	/++
	$(LOCALE_EN_US
		Operator for subscribing to event using handler on right-hand side
	)

	$(LOCALE_RU_RU
		Оператор для подписки на событие, используя обработчик, указанный с правой
		стороны от знака оператора
	)
	+/
	void opOpAssign(string op : "~", C)(C value)
		if (isCallable!C && !isDelegate!C)
	{
		this ~= toDelegate(value);
	}

	/++
		ditto
	+/
	void opOpAssign(string op : "~")(DelegateType value)
	{
		MaybeSynchronous({
			import std.algorithm : canFind;
			
			if (!allowDuplicates && subscribedCallbacks.canFind(value))
				throw new Exception("Attempted to subscribe the same callback multiple times!");
			subscribedCallbacks ~= value;
		});
	}
	
	/++
	$(LOCALE_EN_US
		Operator for unsubscribing from event by handler on right-hand side
	)

	$(LOCALE_RU_RU
		Оператор для отписки от события обработчиком, указанным с правой
		стороны от знака оператора
	)
	+/
	void opOpAssign(string op : "-", C)(C value)
		if (isCallable!C && !isDelegate!C)
	{
		this -= toDelegate(value);
	}

	/++
		ditto
	+/
	void opOpAssign(string op : "-")(DelegateType value)
	{
		MaybeSynchronous({
			import std.algorithm : countUntil, remove;
			
			auto idx = subscribedCallbacks.countUntil(value);
			if (idx == -1)
				throw new Exception("Attempted to unsubscribe a callback that was not subscribed!");
			subscribedCallbacks = subscribedCallbacks.remove(idx);
		});
	}

	/++
	$(LOCALE_EN_US
		Function triggers event and run all subscribed callbacks
	)

	$(LOCALE_RU_RU
		Функция запускает события, выполняя все подписанные на него обработчики
	)
	+/
	private static void rethrowExceptionHandler(DelegateType invokedCallback, Exception exceptionThrown) { throw exceptionThrown; }
	auto fire(ParameterTypeTuple!DelegateType args, void delegate(DelegateType, Exception) exceptionHandler = toDelegate(&rethrowExceptionHandler))
	{
		return MaybeSynchronous({
			import std.traits : ReturnType;
			
			static if (is(ReturnType!DelegateType == void))
			{
				foreach (callback; subscribedCallbacks)
				{
					try
					{
						callback(args);
					}
					catch (Exception e)
					{
						exceptionHandler(callback, e);
					}
				}
			}
			else
			{	ReturnType!DelegateType[] retVals;
				
				foreach (callback; subscribedCallbacks)
				{
					try
					{
						retVals ~= callback(args);
					}
					catch (Exception e)
					{
						exceptionHandler(callback, e);
					}
				}
				
				return retVals;
			}
		});
	}
}

import std.algorithm, std.range, std.conv, std.container, std.typecons, std.typetuple, std.traits;
/++
$(LOCALE_EN_US
	Function returns true if class with TypeInfo $(D_PARAM objTypeinfo) inherits from
	class with TypeInfo $(D_PARAM baseTypeinfo)
)

$(LOCALE_RU_RU
	Функция возвращает Истину, если класс с информацией о типе $(D_PARAM objTypeinfo)
	является производным от класса с информацией о типе $(D_PARAM baseTypeinfo)
)
+/
bool isInheritsOf( TypeInfo_Class objTypeinfo, TypeInfo_Class baseTypeinfo  )
{	while( objTypeinfo )
	{	if( objTypeinfo is baseTypeinfo )
			return true;

		objTypeinfo = objTypeinfo.base;
	}
	return false;
}

/++
$(LOCALE_EN_US
	Struct representing error handling in event-like style
)

$(LOCALE_RU_RU
	Структура предоставляет обработку ошибок в событийном стиле
)
+/
struct ErrorEvent( ErrorHandler, Opts... )
	if( isCallable!(ErrorHandler) )
{
	enum bool isSynchronized = GetEventOption!(EventOption.synchronized_, Opts);
	enum bool allowDuplicateHandlers = GetEventOption!(EventOption.allowDuplicateHandlers, Opts);
	enum bool stopHandlingOnValue = GetEventOption!(EventOption.stopOnValue, Opts);

	static if( stopHandlingOnValue )
		enum ReturnType!(ErrorHandler) stopHandlingValue = GetEventOption!(EventOption.stopHandlingValue, Opts);

	alias ParameterTypeTuple!(ErrorHandler) ParamTypes;

	struct ErrorHandlerPair
	{	ErrorHandler method;
		TypeInfo_Class typeInfo;
	}

	static if (isSynchronized)
		private Object lock = new Object();
	private R MaybeSynchronous(R)(R delegate() d)
	{	static if (isSynchronized)
		{	synchronized (lock)
			{
				return d();
			}
		}
		else
			return d();
	}

	/++
	$(LOCALE_EN_US
 		Function triggers handling error and passes $(D_PARAM params) to handlers.
 		First parameter is always Throwable object.
	)

	$(LOCALE_RU_RU
		Функция запускает обработку ошибки и передает набор параметров $(D_PARAM params)
		обработчикам. Первый параметр - это объект ошибки
	)
	+/
	bool fire(ParamTypes params)
	{	return MaybeSynchronous({
			_sortHandlers();

			static if( stopHandlingOnValue )
				bool stopFlag = false;

			foreach( pair; prioriteErrorPairs )
			{	if( typeid(params[0]).isInheritsOf(pair.typeInfo) )
				{	if( pair.method(params) )
					{	static if( stopHandlingOnValue )
							stopFlag = true;
					}
				}
			}

			static if( stopHandlingOnValue )
			{	if( stopFlag )
					return true;
			}

			foreach( pair; errorPairs )
			{	if( typeid(params[0]).isInheritsOf(pair.typeInfo) )
				{	static if( stopHandlingOnValue )
					{	if( pair.method(params) == stopHandlingValue  )
							return true;
					}
					else
						pair.method(params);
				}
			}
			return false;
		});
	}

	/++
	$(LOCALE_EN_US
 		Service function for sorting handlers by number of base classes for error type
	)

	$(LOCALE_RU_RU
		Служебная функция сортировки обработчиков по количеству базовых классов для класса ошибки
	)
	+/
	private void _sortHandlers()
	{	MaybeSynchronous({
			sort!( (a, b) { return countDerivations(a.typeInfo) > countDerivations(b.typeInfo); } )( prioriteErrorPairs );
			sort!( (a, b) { return countDerivations(a.typeInfo) > countDerivations(b.typeInfo); } )( errorPairs );
		});
	}
	
	/++
	$(LOCALE_EN_US
 		Function for attaching $(D_PARAM handler)  for some type of error
	)

	$(LOCALE_RU_RU
		Функция запускает обработку ошибки и передает набор параметров $(D_PARAM params)
		обработчикам. Первый параметр - это объект ошибки
	)
	+/
	void join(SomeErrorHandler)(SomeErrorHandler handler, bool isPriorite = false)
		if( isCallable!(SomeErrorHandler) && is( ParameterTypeTuple!(SomeErrorHandler)[0] : ParamTypes[0] ) )
	{	alias ParameterTypeTuple!(SomeErrorHandler)[0] SomeError;
		this.join(
			typeid(SomeError),
			(ParamTypes params)
			{	static if( !is ( ReturnType!(ErrorHandler) == void )  )
					return handler( cast(SomeError) params[0], params[1..$] );
				else
					handler( cast(SomeError) params[0], params[1..$] );
			},
			isPriorite
		);
	}

	/++
		ditto
	+/
	void join()(TypeInfo_Class errorTypeinfo, ErrorHandler handler, bool isPriorite = false)
	{	MaybeSynchronous({
			if( isPriorite )
			{	prioriteErrorPairs ~= ErrorHandlerPair( handler, errorTypeinfo );
			}
			else
			{	errorPairs ~= ErrorHandlerPair( handler, errorTypeinfo );
			}
		});
	}

protected:
	ErrorHandlerPair[] prioriteErrorPairs;
	ErrorHandlerPair[] errorPairs;
}

/++
$(LOCALE_EN_US
	Function calculates number of base classes that this class with
	TypeInfo $(D_PARAM typeInfo) derives from
)

$(LOCALE_RU_RU
	Функция считает количество базывых классов для которых данный класс
	с информацией о типе $(D_PARAM typeInfo) является производным
)
+/
size_t countDerivations(TypeInfo_Class typeInfo)
{	size_t result;
	while(typeInfo !is null)
	{	result ++;
		typeInfo = typeInfo.base;
	}
	return result;
}