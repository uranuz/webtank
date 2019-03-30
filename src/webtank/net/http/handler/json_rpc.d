module webtank.net.http.handler.json_rpc;

///Класс исключения для удалённого вызова процедур
class JSON_RPC_Exception : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

import webtank.net.http.handler.iface: IHTTPHandler;

class JSON_RPC_Router: IHTTPHandler
{
	import webtank.net.http.handler.mixins: EventBasedHTTPHandlerImpl;
	import webtank.net.http.context: HTTPContext;
	import webtank.net.http.handler.iface: HTTPHandlingResult;
	import webtank.net.uri_pattern: URIPattern, URIMatchingData;

	import std.json: JSONValue, toJSON, JSON_TYPE, parseJSON, JSONOptions;

	mixin EventBasedHTTPHandlerImpl;

public:
	this(string URIPatternStr, string[string] regExprs, string[string] defaults) {
		_uriPattern = new URIPattern(URIPatternStr, regExprs, defaults);
	}

	this( string URIPatternStr, string[string] defaults = null ) {
		this(URIPatternStr, null, defaults);
	}

	alias JSONValue delegate(ref const(JSONValue), HTTPContext) JSON_RPC_WrapperMethod;

	HTTPHandlingResult customProcessRequest(HTTPContext context)
	{
		import std.uni: toLower;
		JSONValue jResponse;
		//-----Опрос обработчика запроса-----
		auto uriMatchData = _uriPattern.match(context.request.uri.path);
		if( uriMatchData.isMatched )
			context.request.requestURIMatch = uriMatchData;

		bool isRequestMatched =
			uriMatchData.isMatched &&
			toLower(context.request.headers.get("method", null)) == "post";

		//-----Конец опроса обработчика события-----
		onPostPoll.fire(context, isRequestMatched);
		if( !isRequestMatched )
			return HTTPHandlingResult.mismatched;
		context.response.headers["content-type"] = "application/json";

		_processRequestInternal(context, jResponse);
		context.response ~= toJSON(jResponse, false, JSONOptions.specialFloatLiterals);

		return HTTPHandlingResult.handled;
	}

	private void _processRequestInternal(HTTPContext context, ref JSONValue jResponse)
	{
		auto jMessageBody = context.request.messageBody.parseJSON();

		if( jMessageBody.type != JSON_TYPE.OBJECT )
			throw new JSON_RPC_Exception(`JSON-RPC message body must be of object type!!!`);

		string jsonrpc;
		if( "jsonrpc" in jMessageBody )
		{
			if( jMessageBody["jsonrpc"].type == JSON_TYPE.STRING )
				jsonrpc = jMessageBody["jsonrpc"].str;
		}

		if( jsonrpc != "2.0" )
			throw new JSON_RPC_Exception(`Only version 2.0 of JSON-RPC protocol is supported!!!`);

		// Версия должна быть по протоколу. Раз мы проверили, что версия 2.0 - уже можно записать её в результат
		jResponse["jsonrpc"] = "2.0";

		if( "id" in jMessageBody ) {
			jResponse["id"] = jMessageBody["id"]; // По протоколу возвращаем обратно идентификатор сообщения
		} else {
			jResponse["id"] = null; // По протоколу должны вернуть null, если нету в запросе
		}

		string methodName;
		if( "method" in jMessageBody )
		{
			if( jMessageBody["method"].type == JSON_TYPE.STRING )
				methodName = jMessageBody["method"].str;
		}

		if( methodName.length == 0 )
			throw new JSON_RPC_Exception(`JSON-RPC method name must not be empty!!!`);

		auto method = _methods.get(methodName, null);

		if( method is null )
			throw new JSON_RPC_Exception(`JSON-RPC method "` ~ methodName ~ `" is not found by server!!!`);

		//Запрос должен иметь элемент params, даже если параметров
		//не передаётся. В последнем случае должно передаваться
		//либо null в качестве параметра, либо пустой объект {}
		if( "params" in jMessageBody )
		{
			auto paramsType = jMessageBody["params"].type;

			//В текущей реализации принимаем либо объект (список поименованных параметров)
			//либо null, символизирующий их отсутствие
			if( paramsType != JSON_TYPE.OBJECT && paramsType != JSON_TYPE.NULL )
				throw new JSON_RPC_Exception(`JSON-RPC "params" property should be of null or object type!!!`);
		}
		else
			throw new JSON_RPC_Exception(`JSON-RPC "params" property should be in JSON request object!!!`);

		jResponse["result"] = method(jMessageBody["params"], context); // Вызов метода
	}

	import std.traits: isSomeFunction, fullyQualifiedName;
	import std.functional: toDelegate;
	JSON_RPC_Router join(alias Method)(string methodName = null)
		if( isSomeFunction!(Method) )
	{
		auto nameOfMethod = ( methodName.length == 0 ? fullyQualifiedName!(Method) : methodName );

		if( nameOfMethod in _methods )
			throw new JSON_RPC_Exception(`JSON-RPC method "` ~ nameOfMethod ~ `" is already registered in the system!!!`);

		_methods[nameOfMethod] = toDelegate(  &callJSON_RPC_Method!(Method) );
		return this;
	}

protected:

	JSON_RPC_WrapperMethod[string] _methods;

	URIPattern _uriPattern;
}

template callJSON_RPC_Method(alias Method)
{
	import webtank.net.http.context: HTTPContext;
	import webtank.common.std_json.from: fromStdJSON;
	import webtank.common.std_json.to: toStdJSON;

	import std.traits: Parameters, ReturnType, ParameterIdentifierTuple, ParameterDefaults;
	import std.json: JSONValue, JSON_TYPE;
	import std.conv: to;
	import std.typecons: Tuple;

	alias ParamTypes = Parameters!(Method);
	alias ResultType = ReturnType!(Method);
	alias ParamNames = ParameterIdentifierTuple!(Method);
	alias MethDefaults = ParameterDefaults!(Method);

	JSONValue callJSON_RPC_Method(ref const(JSONValue) jParams, HTTPContext context)
	{
		JSONValue result = null; // По-умолчанию в качестве результата null
		size_t expectedParamsCount = 0; // Ожидаемое число параметров в jParams

		//Считаем количество параметров, которые должны были быть переданы
		foreach( type; ParamTypes )
		{
			static if( !is(type: HTTPContext) ) {
				++expectedParamsCount;
			}
		}

		if( expectedParamsCount > 0 && (jParams.type != JSON_TYPE.OBJECT || jParams.object.length != expectedParamsCount) ) {
			throw new JSON_RPC_Exception(
				`Expected JSON object with ` ~ expectedParamsCount.to!string ~ ` params in JSON-RPC call, but got: `
				~ (jParams.type == JSON_TYPE.OBJECT ? jParams.object.length.to!string : jParams.type.to!string)
			);
		}

		Tuple!(ParamTypes) argTuple;
		foreach( i, type; ParamTypes )
		{
			static if( is(type : HTTPContext) )
			{
				auto typedContext = cast(type) context;
				if( !typedContext ) {
					throw new JSON_RPC_Exception(
						`Error in attempt to convert parameter "` ~ ParamNames[i] ~ `" to type "` ~ type.stringof ~ `". Context reference is null!`
					);
				}
				argTuple[i] = typedContext; //Передаём контекст при необходимости
				continue;
			}
			else
			{
				if( auto paramPtr = ParamNames[i] in jParams ) {
					argTuple[i] = fromStdJSON!(type)(*paramPtr);
				}
				else
				{
					static if( is( MethDefaults[i] == void ) ) {
						// Значения по умолчанию нет - значит отсутствие значения - ошибка
						throw new JSON_RPC_Exception(
							`Expected JSON-RPC parameter ` ~ ParamNames[i] ~ ` is not found in params object!!!`
						);
					} else {
						// Если метод имеет значение по умолчанию, то учитываем его
						argTuple[i] = MethDefaults[i];
					}
				}
			}
		}

		static if( is( ResultType == void ) ) {
			Method(argTuple.expand);
		} else {
			result = toStdJSON( Method(argTuple.expand) );
		}

		return result;
	}
}


