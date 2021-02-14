module webtank.security.auth.core.by_password;

import webtank.db.iface.factory: IDatabaseFactory;

import webtank.net.http.input: HTTPInput;
import webtank.net.http.context: HTTPContext;

import webtank.security.auth.iface.user_identity: IUserIdentity;


// Аутентификация по логину и паролю. Доп. параметры нужны для привязки сессии к IP-адресу
// и идентификационной строке программы-клиента.
// Бросается исключениями AuthException, если вход не выполнен, но процесс проходит штатно.
// Другие типы исключений, вероятно, свидетельствуют об ошибке в алгоритме.
// При успешном входе возвращает удостоверение пользователя
IUserIdentity authByPasswordInternal(
	IDatabaseFactory dbFactory,
	string login,
	string password,
	string clientAddress,
	string userAgent
) {
	import webtank.datctrl.record_format: RecordFormat, PrimaryKey;

	import webtank.db.query_params: queryParams;
	import webtank.db.datctrl: getRecord, getScalar;

	import webtank.security.auth.core.change_password: changeUserPassword;
	import webtank.security.auth.core.crypto: checkPasswordExt, generateSessionId;
	import webtank.security.auth.core.utils: getAuthDB;
	import webtank.security.auth.common.exception: AuthException;
	import webtank.security.auth.core.consts: minLoginLength, minPasswordLength;
	import webtank.security.auth.common.user_identity: CoreUserIdentity;
	import webtank.security.auth.common.session_id: SessionId;

	import std.array: join;
	import std.exception: enforce;
	import std.utf: count;
	import std.datetime: DateTime, Clock;
	import std.base64: Base64URL;

	enforce!AuthException(dbFactory !is null, `Expected instance of IDatabaseFactory`);
	enforce!AuthException(login.count >= minLoginLength, `Login length is too short`);
	enforce!AuthException(password.count >= minPasswordLength, `Password length is too short`);

	auto authDB = dbFactory.getAuthDB();

	//Делаем запрос к БД за информацией о пользователе
	auto userRec = authDB.queryParams(
`select
	su.num,
	su.pw_hash,
	su.pw_salt,
	su.reg_timestamp,
	su.name,
	su.email,
	to_json(coalesce(
		array_agg(R.name) filter(where nullif(R.name, '') is not null), ARRAY[]::text[]
	)) "roles",
	su.tourist_num
from site_user su
left join user_access_role UR
	on UR.user_num = su.num
left join access_role R
	on R.num = UR.role_num
where login = $1::text
	and su.is_blocked is not true
group by su.num, su.pw_hash, su.pw_salt, su.reg_timestamp, su.name, su.email`, login
	).getRecord(RecordFormat!(
		PrimaryKey!(size_t, "num"),
		string, "pwHash",
		string, "pwSalt",
		DateTime, "regTimestamp",
		string, "name",
		string, "email",
		string[], "roles",
		size_t, "tourist_num"
	)());

	string userNum = userRec.getStr!"num";
	string validEncodedPwHash = userRec.getStr!"pwHash";
	string pwSalt = userRec.getStr!"pwSalt";
	DateTime regDateTime = userRec.get!"regTimestamp";

	string rolesStr = userRec.get!"roles"().join(`;`);
	string name = userRec.getStr!"name";
	string email = userRec.getStr!"email";
	string touristNum = userRec.getStr!"tourist_num";

	auto passStatus = checkPasswordExt(validEncodedPwHash, password, pwSalt, regDateTime.toISOExtString());

	enforce!AuthException(passStatus.checkResult, `Password check failed`);

	if( passStatus.isOldHash )
	{
		// Делаем апгрейд хэша пароля пользователя при его входе в систему
		// Здесь уже проверили пароль. Второй раз проверять не надо
		enforce!AuthException(
			changeUserPassword!(/*doPwCheck=*/false)(dbFactory, login, null, password),
			`Unable to update password hash`);
	}

	SessionId sid = generateSessionId(login, rolesStr, Clock.currTime().toISOString());

	string authRes = authDB.queryParams(
`insert into "session" (
	"sid", "site_user_num", "created", "client_address", "user_agent"
)
values(
	$1::text,
	$2::integer,
	current_timestamp at time zone 'UTC',
	$3::text,
	$4::text
)
returning 'authenticated'`,
		Base64URL.encode(sid),
		userNum,
		clientAddress,
		userAgent
	).getScalar!string;

	enforce!AuthException(
		authRes == "authenticated",
		`Expected "authenticated" message is sid write result`);

	string[string] userData = [
		"userNum": userNum,
		"roles": rolesStr,
		"email": email,
		"touristNum": touristNum
	];
	//Аутентификация завершена успешно
	return new CoreUserIdentity(login, name, userRec.get!"roles"(), userData, sid);
}

import webtank.ivy.service.main: MainServiceContext;
import std.typecons: Tuple;

// Аутентификация по логину и паролю с установкой удостоверения пользователя в контекст,
// а также обновления данных сессии в запросе и ответе.
// Если вход не выполнен, но проходит штатно, то в контексте устанавливается удостоверение анонимного пользователя
// Неожиданные ошибки входа будут выброшены наружу
Tuple!(
	string, `userLogin`,
	bool, `isAuthFailed`,
	bool, `isAuthenticated`
)
authByPassword(
	MainServiceContext ctx,
	string userLogin = null,
	string userPassword = null,
	string redirectTo = null
) {
	import webtank.net.http.headers.consts: CookieName, HTTPHeader;
	import webtank.security.auth.common.user_identity: CoreUserIdentity;
	import webtank.security.auth.common.anonymous_user: AnonymousUser;
	import webtank.security.auth.common.exception: AuthException;
	import webtank.net.uri: URI;

	import std.base64: Base64URL;
	import std.exception: ifThrown;
	import std.range: empty;

	typeof(return) res;

	// Если логин или пароль пустые, то просто ничё ни делаем.
	// Не считаем это даже за попытку аутентификации.
	// Если пользователь до этого был залогинен, то у него ничего не меняется
	if( userLogin.empty || userPassword.empty )
		return res;
	res.userLogin = userLogin;

	string userIP = ctx.request.headers[HTTPHeader.XRealIP];
	string userAgent = ctx.request.headers[HTTPHeader.UserAgent];

	try {
		ctx.user = authByPasswordInternal(ctx.service, userLogin, userPassword, userIP, userAgent);
	} catch(Exception exc) {
		ctx.service.log.warn(exc);
	}

	if( ctx.user is null ) {
		res.isAuthFailed = true;
		ctx.user = new AnonymousUser;
	}

	res.isAuthenticated = ctx.user.isAuthenticated && !res.isAuthFailed;

	if( CoreUserIdentity mkkIdentity = cast(CoreUserIdentity) ctx.user )
	{
		// Устанавливаем аутентификационные данные в запрос и ответ
		string sidStr = Base64URL.encode(mkkIdentity.sessionId) ;
		ctx.request.cookies[CookieName.SessionId] = sidStr;
		ctx.response.cookies[CookieName.SessionId] = sidStr;

		ctx.response.cookies[CookieName.SessionId].path = "/";
	}

	if( ctx.user.isAuthenticated )
	{
		ctx.request.cookies[CookieName.UserLogin] = ctx.user.id;
		ctx.response.cookies[CookieName.UserLogin] = ctx.user.id;
		ctx.response.cookies[CookieName.UserLogin].path = "/";
	}
	else
	{
		// Удаляем возможный старый __sid__, если не удалось получить
		ctx.request.cookies[CookieName.SessionId] = null;
		ctx.response.cookies[CookieName.SessionId] = null;
	}
	return res;
}