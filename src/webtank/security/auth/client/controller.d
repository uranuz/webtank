module webtank.security.auth.client.controller;

import webtank.security.auth.iface.controller: IAuthController;
import webtank.security.auth.iface.user_identity: IUserIdentity;

import webtank.security.auth.common.anonymous_user: AnonymousUser;
import webtank.security.auth.common.user_identity: CoreUserIdentity;
import webtank.security.auth.common.session_id: SessionId;

import webtank.net.http.context: HTTPContext;
import webtank.net.utils;


//import mkk.common.service;
import webtank.net.std_json_rpc_client;

///Класс управляет выдачей билетов для доступа
class AuthClientController: IAuthController
{
	this() {}
public:
	///Реализация метода аутентификации контролёра доступа
	override IUserIdentity authenticate(Object context)
	{
		auto httpCtx = cast(HTTPContext) context;

		if( httpCtx !is null ) {
			return authenticateSession(httpCtx);
		}
		return new AnonymousUser;
	}

	///Метод выполняет аутентификацию сессии для HTTP контекста
	///Возвращает удостоверение пользователя
	IUserIdentity authenticateSession(HTTPContext ctx)
	{
		//debug import std.stdio: writeln;
		//debug writeln(`TRACE authenticateSession 1`);
		import std.json: JSONType, JSONValue;
		// Запрос получает минимальную информацию о пользователе по Ид. сессии в контексте
		auto jUserInfo = ctx.endpoint(`authService`).remoteCall!JSONValue(`auth.baseUserInfo`);

		//debug writeln(`TRACE authenticateSession jUserInfo: `, jUserInfo);

		import std.exception: enforce;
		enforce(jUserInfo.type == JSONType.object, `Base user info expected to be object!`);

		if( `userNum` !in jUserInfo || jUserInfo[`userNum`].type != JSONType.integer ) {
			return new AnonymousUser;
		}
		//debug writeln(`TRACE authenticateSession 2`);

		import std.base64: Base64URL;
		SessionId sid;
		Base64URL.decode(ctx.request.cookies.get(`__sid__`), sid[]);

		import std.algorithm: splitter, filter;
		import std.array: array;

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
		//debug writeln(`TRACE authenticateSession 3`);
		return new CoreUserIdentity(login, name, accessRoles, /*data=*/null, sid);
	}
}