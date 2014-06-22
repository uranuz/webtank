module webtank.net.http.json_rpc_handler;

import std.string, std.conv, std.traits, std.typecons, std.json, std.functional;

import webtank.net.http.handler, webtank.common.serialization, webtank.net.http.context, webtank.net.uri_pattern;

///Класс исключения для удалённого вызова процедур
class JSON_RPC_Exception : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class JSON_RPC_Router: EventBasedHTTPHandler
{	
	this( string URIPatternStr, string[string] regExprs, string[string] defaults )
	{	_uriPattern = new URIPattern(URIPatternStr, regExprs, defaults);
	}
	
	this( string URIPatternStr, string[string] defaults = null )
	{	this(URIPatternStr, null, defaults);
	}
	
	alias JSONValue delegate( ref const(JSONValue), HTTPContext ) JSON_RPC_WrapperMethod;
	
	override HTTPHandlingResult customProcessRequest(HTTPContext context)
	{	//-----Опрос обработчика запроса-----
		auto uriData = _uriPattern.match(context.request.uri.path);
		
		bool isRequestMatched =
			uriData.isMatched &&
			toLower( context.request.headers.get("method", null) ) == "post";
		
		//-----Конец опроса обработчика события-----
		onPostPoll.fire(context, isRequestMatched);
		if( !isRequestMatched )
			return HTTPHandlingResult.mismatched;
		
		auto jMessageBody = context.request.bodyJSON;
		
		if( jMessageBody.type != JSON_TYPE.OBJECT )
			throw new JSON_RPC_Exception(`JSON-RPC message body must be of object type!!!`);
		
		string jsonrpc;
		if( "jsonrpc" in jMessageBody.object )
		{	if( jMessageBody["jsonrpc"].type == JSON_TYPE.STRING )
				jsonrpc = jMessageBody["jsonrpc"].str;
		}
		
		if( jsonrpc != "2.0" )
			throw new JSON_RPC_Exception(`Only version 2.0 of JSON-RPC protocol is supported!!!`);
			
		string methodName;
		if( "method" in jMessageBody.object )
		{	if( jMessageBody["method"].type == JSON_TYPE.STRING )
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
		if( "params" in jMessageBody.object )
		{	auto paramsType = jMessageBody["params"].type;
		
			//В текущей реализации принимаем либо объект (список поименованных параметров)
			//либо null, символизирующий их отсутствие
			if( paramsType != JSON_TYPE.OBJECT && paramsType != JSON_TYPE.NULL )
				throw new JSON_RPC_Exception(`JSON-RPC "params" property should be of null or object type!!!`);
		}
		else
			throw new JSON_RPC_Exception(`JSON-RPC "params" property should be in JSON request object!!!`);
		
		JSONValue[string] jResponseArray;
		
		//Вызов метода
		jResponseArray["result"] = method( jMessageBody["params"], context );
		
		jResponseArray["jsonrpc"] = "2.0";
		jResponseArray["id"] = jMessageBody["id"];
		
		JSONValue jResponse = jResponseArray;
		
		context.response ~= toJSON( &jResponse );
		
		return HTTPHandlingResult.handled;
	}
	
	JSON_RPC_Router join(alias Method)(string methodName = null)
		if( isSomeFunction!(Method) )
	{	auto nameOfMethod = ( methodName.length == 0 ? fullyQualifiedName!(Method) : methodName );
	
		if( nameOfMethod in _methods )
			throw new JSON_RPC_Exception(`JSON-RPC method` ~ nameOfMethod ~ ` is already registered in system!!!`);
		
		_methods[nameOfMethod] = toDelegate(  &callJSON_RPC_Method!(Method) );
		return this;
	}
	
protected:
	
	JSON_RPC_WrapperMethod[string] _methods;
	
	URIPattern _uriPattern;
}

template callJSON_RPC_Method(alias Method)
{	
	import std.traits, std.json, std.conv, std.typecons;
	alias ParameterTypeTuple!(Method) ParamTypes;
	alias ReturnType!(Method) ResultType;
	alias ParameterIdentifierTuple!(Method) ParamNames;
	
	JSONValue callJSON_RPC_Method(ref const(JSONValue) jValue, HTTPContext context)
	{	JSONValue result = null; //По-умолчанию в качестве результата null
		
		static if( ParamTypes.length == 0 )
		{	
			if( jValue.type == JSON_TYPE.NULL   )
			{	//Don't remove!!!
			}
			else if( jValue.type == JSON_TYPE.OBJECT )
			{	if( jValue.object.length != 0 )
					throw new JSON_RPC_Exception(
						"Calling method without params. But got JSON object with " 
						~ jValue.object.length.to!string ~ " parameters "
					);
			}
			else
				throw new JSON_RPC_Exception( 
					"Unsupported JSON value type!!!"
				);
			
			static if( is( ResultType == void ) )
				Method(); //Вызов метода без параметров и возвращаемого значения
			else
				result = getStdJSON( Method() ); //Вызов метода без параметров с возвращаемым значением
		}
		else
		{	
			if( jValue.type == JSON_TYPE.OBJECT )
			{	size_t jParamsCount = 0;
				
				//Считаем количество параметров, которые должны были быть переданы
				foreach( type; ParamTypes )
				{	static if( !is( type: HTTPContext )  )
						jParamsCount++;
				}
				
				if( jParamsCount == jValue.object.length )
				{	
// 					pragma(msg, ParamTypes);
					Tuple!(ParamTypes) argTuple;
// 					pragma(msg, typeof(argTuple));
					foreach( i, type; ParamTypes )
					{	pragma(msg, "Current type is ", type, " ", i);
						static if( is( type : HTTPContext )  )
						{	argTuple[i] = cast(type) context; //Передаём контекст при необходимости
							continue;
						}
						else 
						{	if( ParamNames[i] in jValue.object )
							{	
								auto dValue = getDLangValue!(type)( jValue.object[ ParamNames[i] ] );
								pragma(msg, "Typeof dValue is ", typeof(dValue));
								argTuple[i] = dValue;
							}
							else
								throw new JSON_RPC_Exception( 
									"Expected JSON-RPC parameter " ~ ParamNames[i]
									~ " is not found in param object!!!"
								);
						}
					}
					
					static if( is( ResultType == void ) )
						Method(argTuple.expand);
					else
						result = getStdJSON( Method(argTuple.expand) );
				}
				else
					throw new JSON_RPC_Exception( 
						"Expected JSON-RPC params count is " ~ jParamsCount.to!string
						~ " but got " ~ jValue.object.length.to!string
					);
			}
			else
				throw new JSON_RPC_Exception( 
					"Unsupported JSON value type!!!"
				);
		}
		
		return result;
	}
}


