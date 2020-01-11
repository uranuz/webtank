module webtank.net.http.handler.web_form_api_page_route;

import webtank.net.http.handler.iface: IHTTPHandler;
import webtank.net.uri_pattern: URIPattern;
import webtank.net.http.handler.iface: ICompositeHTTPHandler;
import webtank.net.http.context: HTTPContext;

/// Обработчик метода, принимающий данные в формате веб-формы,
/// и возвращающий в виде как JSON-RPC (ответ - поле result, ошибка - поле error)
class WebFormAPIPageRoute: IHTTPHandler
{
	import webtank.net.http.handler.iface: HTTPHandlingResult;
	import webtank.net.uri_pattern: URIMatchingData;
	import webtank.net.http.headers.consts: HTTPHeader;

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
		URIMatchingData uriMatchData = _uriPattern.match(context.request.uri.path);
		if( !uriMatchData.isMatched )
			return HTTPHandlingResult.mismatched;

		context.request.requestURIMatch = uriMatchData;
		context.response.headers[HTTPHeader.ContentType] = "application/json";
		JSONValue jResponse = [
			"jsonrpc": JSONValue("2.0"),
			"id": JSONValue(),
			"result": _handler(context)
		];
		context.response ~= toJSON(jResponse, false, JSONOptions.specialFloatLiterals);

		return HTTPHandlingResult.handled; // Запрос обработан
	}

	override JSONValue toStdJSON()
	{
		import webtank.common.std_json.to: toStdJSON;
		return JSONValue([
			`kind`: JSONValue(typeof(this).stringof),
			`uriPattern`: _uriPattern.toStdJSON()
		]);
	}
}

import std.traits: isSomeFunction;
import std.functional: toDelegate;
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
	import std.traits: Parameters, ParameterIdentifierTuple, ParameterDefaults, ReturnType;
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

			// Получаем данные из плейсхолдеров в адресной строке
			formDataToStruct(ctx.request.requestURIMatch, argTuple[i]);
			formDataToStruct(ctx.request.requestURIMatch, argTuple[i], paramName);
		}
		else
		{
			import webtank.common.conv: conv;
			if( auto valPtr = paramName in ctx.request.form ) {
				argTuple[i] = (*valPtr).conv!(ParamType);
			}
			
			if( auto valPtr = paramName in ctx.request.requestURIMatch ) {
				argTuple[i] = (*valPtr).conv!(ParamType);
			}
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