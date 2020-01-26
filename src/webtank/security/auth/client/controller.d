module webtank.security.auth.client.controller;

import webtank.security.auth.iface.controller: IAuthController;

///Класс управляет выдачей билетов для доступа
class AuthClientController: IAuthController
{
	import webtank.net.service.iface: IServiceConfig;
	import webtank.net.std_json_rpc_client: RemoteCallInfo, getAllowedRequestHeaders, remoteCall;
	import webtank.net.http.input: HTTPInput;
	import webtank.security.auth.iface.user_identity: IUserIdentity;

	import webtank.security.auth.common.anonymous_user: AnonymousUser;
	import webtank.security.auth.common.user_identity: CoreUserIdentity;
	import webtank.security.auth.common.session_id: SessionId;

	import webtank.net.http.headers.cookie.consts: CookieName;
	import webtank.security.auth.common.exception: AuthException;

	import std.exception: enforce;

	this(IServiceConfig config)
	{
		enforce(config !is null, `Expected instance of IServiceConfig`);
		_config = config;
	}
private:
	IServiceConfig _config;

public:
	///Метод выполняет аутентификацию сессии для HTTP контекста
	///Возвращает удостоверение пользователя
	override IUserIdentity authenticate(HTTPInput request)
	{
		import std.json: JSONType, JSONValue;
		import std.base64: Base64URL;
		import std.algorithm: splitter, filter;
		import std.array: array;
		import std.exception: enforce;

		// Запрос получает минимальную информацию о пользователе по Ид. сессии в контексте
		auto callInfo = RemoteCallInfo(_config.endpoint(`authService`), getAllowedRequestHeaders(request));
		JSONValue jUserInfo = callInfo.remoteCall!JSONValue(`auth.baseUserInfo`);

		enforce!AuthException(
			jUserInfo.type == JSONType.object,
			`Base user info expected to be object!`);

		auto userNumPtr = `userNum` in jUserInfo;
		enforce!AuthException(
			userNumPtr !is null,
			`Expected "userNum" field in base user info`);
		enforce!AuthException(
			userNumPtr.type == JSONType.integer,
			`Expected "userNum" field expected to be integer`);

		SessionId sid;
		Base64URL.decode(request.cookies.get(CookieName.SessionId), sid[]);

		//Получаем информацию о пользователе из результата запроса: логин, имя, роли доступа
		string login; string name; string[] accessRoles;
		if( auto it = `login` in jUserInfo ) {
			login = it.type == JSONType.string? it.str: null;
		}
		if( auto it = `name` in jUserInfo ) {
			name = it.type == JSONType.string? it.str: null;
		}
		if( auto it = `accessRoles` in jUserInfo ) {
			accessRoles = it.type == JSONType.string? it.str.splitter(`;`).filter!( (it) => it.length > 0 ).array: null;
		}
		return new CoreUserIdentity(login, name, accessRoles, /*data=*/null, sid);
	}
}