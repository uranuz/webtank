module webtank.security.auth.core.controller;

import std.conv, std.digest.digest, std.datetime, std.utf, std.base64 : Base64URL;

import webtank.security.auth.iface.controller: IAuthController;
import webtank.security.auth.iface.user_identity: IUserIdentity;

import webtank.security.auth.common.anonymous_user: AnonymousUser;
import webtank.security.auth.common.exception: AuthException;
import webtank.security.auth.common.user_identity: CoreUserIdentity;

import webtank.security.auth.common.session_id: SessionId, sessionIdStrLength;
//import webtank.security.auth.core.crypto;

import webtank.net.http.context: HTTPContext;

import webtank.db.database: IDatabase, queryParams;

//import webtank.common.conv;


enum uint minLoginLength = 3;  //Минимальная длина логина
enum uint minPasswordLength = 8;  //Минимальная длина пароля
enum size_t sessionLifetime = 180; //Время жизни сессии в минутах
enum size_t emailConfirmDaysLimit = 3;  // Время на подтверждение адреса электронной почты пользователем

/// Класс управляет выдачей билетов для доступа
class AuthCoreController: IAuthController
{
protected:
	IDatabase delegate() _getAuthDB;

public:
	import std.exception: enforce;

	this(IDatabase delegate() getAuthDB)
	{
		enforce(getAuthDB !is null, `Auth DB method reference is null!!!`);
		_getAuthDB = getAuthDB;
	}

	///Реализация метода аутентификации контролёра доступа
	override IUserIdentity authenticate(Object context)
	{
		if( auto httpCtx = cast(HTTPContext) context ) {
			return authenticateSession(httpCtx);
		}
		return new AnonymousUser;
	}

	IUserIdentity authenticateSession(HTTPContext context)
	{
		try {
			return authenticateSessionImpl(context);
		} catch(AuthException) {
			// Add debug code here
		}
		return new AnonymousUser;
	}

	///Метод выполняет аутентификацию сессии для HTTP контекста
	///Возвращает удостоверение пользователя
	IUserIdentity authenticateSessionImpl(HTTPContext context)
	{
		import std.conv: text;
		auto req = context.request;
		string SIDString = req.cookies.get("__sid__", null);

		enforce!AuthException(SIDString.length == sessionIdStrLength, `Incorrect length of sid string`);

		SessionId sessionId;
		Base64URL.decode(SIDString, sessionId[]);

		enforce!AuthException(sessionId != SessionId.init, `Empty sid`);

		//Делаем запрос к БД за информацией о сессии
		auto sidQueryRes = _getAuthDB().query(
			//Получим адрес машины и тип клиентской программы, если срок действия не истек или ничего
`select client_address, user_agent
from session
where
	sid = '` ~ Base64URL.encode(sessionId) ~ `'
	and current_timestamp at time zone 'UTC' <= (created + '` ~ sessionLifetime.text ~ ` minutes')`
		);

		enforce!AuthException(sidQueryRes.recordCount == 1, `Unable to find sid`);
		enforce!AuthException(sidQueryRes.fieldCount == 2, `Expected 2 field in sid search result`);

		//Проверяем адрес и клиентскую программу с имеющимися при создании сессии
		enforce!AuthException(
			req.headers.get("x-real-ip", null) == sidQueryRes.get(0, 0, null),
			`User IP-address mismatch`);
		enforce!AuthException(
			req.headers.get("user-agent", null) == sidQueryRes.get(1, 0, null),
			`User agent mismatch`);

		import webtank.datctrl.record_format: RecordFormat, PrimaryKey;
		import webtank.db.datctrl_joint: getRecordSet;
		static immutable userDataRecFormat = RecordFormat!(
			PrimaryKey!(size_t, "num"),
			string, "email",
			string, "login",
			string, "name",
			string[], "roles"
		)();

		//Делаем запрос к БД за информацией о пользователе
		auto userRS = _getAuthDB().queryParams(
`select
	su.num, su.email, su.login, su.name,
	to_json(coalesce(
		array_agg(R.name) filter(where nullif(R.name, '') is not null), ARRAY[]::text[]
	)) "roles"
from session
join site_user su
	on su.num = site_user_num
left join user_access_role UR
	on UR.user_num = su.num
left join access_role R
	on R.num = UR.role_num
where session.sid = $1::text
	and su.is_blocked is not true
group by su.num, su.email, su.login, su.name`, Base64URL.encode(sessionId)
		).getRecordSet(userDataRecFormat);

		enforce!AuthException(userRS.length > 0, `Unable to get info about user`);

		auto userRec = userRS.front;
		string[string] userData = [
			"userNum": userRec.getStr!"num",
			"email": userRec.getStr!"email"
		];

		import std.array: join;
		//Получаем информацию о пользователе из результата запроса
		return new CoreUserIdentity(
			userRec.getStr!"login",
			userRec.getStr!"name",
			userRec.get!"roles"(),
			userData,
			sessionId
		);
	}

	IUserIdentity authenticateByPassword(
		string login,
		string password,
		string clientAddress,
		string userAgent
	) {
		try {
			return authenticateByPasswordImpl(login, password, clientAddress, userAgent);
		} catch(AuthException exc) {
			// Add debug code here
			debug {
				import std.stdio;
				writeln(exc.msg);
			}
		}
		return new AnonymousUser;
	};

	//Функция выполняет вход пользователя с логином и паролем,
	//происходит генерация Ид сессии, сохранение его в БД
	IUserIdentity authenticateByPasswordImpl(
		string login,
		string password,
		string clientAddress,
		string userAgent
	) {
		enforce!AuthException(login.count >= minLoginLength, `Login length is too short`);
		enforce!AuthException(password.count >= minPasswordLength, `Password length is too short`);

		import webtank.datctrl.record_format: RecordFormat, PrimaryKey;
		import webtank.db.datctrl_joint: getRecordSet;
		import webtank.security.auth.core.controller: changeUserPassword;
		import webtank.security.auth.core.crypto: checkPasswordExt, generateSessionId;
		static immutable userPwDataRecFormat = RecordFormat!(
			PrimaryKey!(size_t, "num"),
			string, "pwHash",
			string, "pwSalt",
			DateTime, "regTimestamp",
			string, "name",
			string, "email",
			string[], "roles",
			size_t, "tourist_num"
		)();

		//Делаем запрос к БД за информацией о пользователе
		auto userRS = _getAuthDB().queryParams(
`select
	su.num, su.pw_hash, su.pw_salt, su.reg_timestamp, su.name, su.email,
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
		).getRecordSet(userPwDataRecFormat);

		enforce!AuthException(userRS.length > 0, `Unable to find user by login`);

		auto userRec = userRS.front;

		string userNum = userRec.getStr!"num";
		string validEncodedPwHash = userRec.getStr!"pwHash";
		string pwSalt = userRec.getStr!"pwSalt";
		DateTime regDateTime = userRec.get!"regTimestamp";

		import std.array: join;
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
				changeUserPassword!(/*doPwCheck=*/false)(_getAuthDB, login, null, password),
				`Unable to update password hash`);
		}

		SessionId sid = generateSessionId(login, rolesStr, Clock.currTime().toISOString());

		auto newSIDStatusRes = _getAuthDB().queryParams(
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
		);

		enforce!AuthException(
			newSIDStatusRes.recordCount == 1,
			`Expected one record in sid write result`);
		enforce!AuthException(
			newSIDStatusRes.get(0, 0, null) == "authenticated",
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

	// Эта обертка над authenticateByPassword получает некоторые параметры из контекста.
	// Выполняет аутентификацию, устанавливает идентификатор сессии в Cookie запроса и ответа,
	// устанавливает св-во user в контексте
	IUserIdentity authenticateByPassword(HTTPContext ctx, string login, string password)
	{
		import std.base64: Base64URL;

		IUserIdentity userIdentity = authenticateByPassword(
			login,
			password,
			ctx.request.headers[`x-real-ip`],
			ctx.request.headers[`user-agent`]
		);
		CoreUserIdentity mkkIdentity = cast(CoreUserIdentity) userIdentity;
		if( mkkIdentity !is null )
		{
			string sidStr = Base64URL.encode(mkkIdentity.sessionId) ;
			ctx.request.cookies[`__sid__`] = sidStr;
			ctx.response.cookies[`__sid__`] = sidStr;
		}
		else
		{
			// Удаляем возможный старый __sid__, если не удалось получить
			ctx.request.cookies[`__sid__`] = null;
			ctx.response.cookies[`__sid__`] = null;
		}
		// Проставляем path (только для заголовка ответа), чтобы не было случайностей
		ctx.response.cookies[`__sid__`].path = "/";

		// Для удобства установим логин пользователя
		ctx.request.cookies[`user_login`] = userIdentity.id;
		ctx.response.cookies[`user_login`] = userIdentity.id;
		ctx.response.cookies[`user_login`].path = "/";
		ctx.user = userIdentity; 
		return userIdentity;
	}

	bool logout(IUserIdentity userIdentity)
	{
		CoreUserIdentity mkkUserIdentity = cast(CoreUserIdentity) userIdentity;

		if( !mkkUserIdentity ) {
			return false;
		}

		if( !mkkUserIdentity.isAuthenticated ) {
			return true;
		}

		size_t userNum;
		try {
			userNum = mkkUserIdentity.data.get(`userNum`, null).to!size_t;
		} catch( ConvException e ) {
			return false;
		}

		// Сносим все сессии пользователя из базы
		_getAuthDB().query(
			`delete from session where "site_user_num" = ` ~ userNum.to!string ~ `;`
		);

		mkkUserIdentity.invalidate(); // Затираем текущий экземпляр удостоверения

		return true;
	}
}

bool changeUserPassword(bool doPwCheck = true)(
	IDatabase delegate() _getAuthDB,
	string login,
	string oldPassword,
	string newPassword,
	bool useScr = false
) {
	import webtank.security.auth.core.crypto: makePasswordHashCompat, checkPassword;
	assert(_getAuthDB, `getAuthDB method is not specified!`);
	// import mkk.logging: SiteLoger; TODO: Устаревшая вещь - нужно переделать

	// SiteLoger.info( `Проверка длины нового пароля`, `Смена пароля пользователя` );
	if( newPassword.length < minPasswordLength )
	{
		// SiteLoger.info( `Новый пароль слишком короткий`, `Смена пароля пользователя` );
		return false;
	}

	// SiteLoger.info( `Подключаемся к базе данных аутентификации`, `Смена пароля пользователя` );
	// SiteLoger.info( `Получаем данные о пользователе из БД`, `Смена пароля пользователя` );
	auto userQueryRes = _getAuthDB().queryParams(
`select num, pw_hash, pw_salt, reg_timestamp
from site_user
where login = $1`, login
	);
	// SiteLoger.info( `Запрос данных о пользователе успешно завершен`, `Смена пароля пользователя` );

	import webtank.common.conv: fromPGTimestamp;
	DateTime regDateTime = fromPGTimestamp!DateTime(userQueryRes.get(3, 0, null));
	string regTimestampStr = regDateTime.toISOExtString();

	static if( doPwCheck )
	{
		string oldPwHashStr = userQueryRes.get(1, 0, null);
		string oldPwSaltStr = userQueryRes.get(2, 0, null);

		// SiteLoger.info( `Проверка старого пароля пользователя`, `Смена пароля пользователя` );
		if( !checkPassword(oldPwHashStr, oldPassword, oldPwSaltStr, regTimestampStr) )
		{
			// SiteLoger.info( `Неверный старый пароль`, `Смена пароля пользователя` );
			return false;
		}
		// SiteLoger.info( `Проверка старого пароля успешно завершилась`, `Смена пароля пользователя` );
	}

	import std.uuid : randomUUID;
	string pwSaltStr = randomUUID().toString();
	auto hashRes = makePasswordHashCompat(newPassword, pwSaltStr, regTimestampStr, useScr);

	// SiteLoger.info( `Выполняем запрос на смену пароля`, `Смена пароля пользователя` );
	auto changePwQueryRes = _getAuthDB().queryParams(
`update site_user set pw_hash = $1, pw_salt = $2
where login = $3
returning 'pw_changed';`,
		hashRes.pwHashStr, pwSaltStr, login
	);

	// SiteLoger.info( `Проверка успешности выполнения запроса смены пароля`, `Смена пароля пользователя` );
	if( changePwQueryRes.get(0, 0, null) == "pw_changed" )
	{
		// SiteLoger.info( `Успешно задан новый пароль`, `Смена пароля пользователя` );
		return true;
	}
	// SiteLoger.info( `Запрос смены пароля завершился с неверным результатом`, `Смена пароля пользователя` );

	return false;
}
