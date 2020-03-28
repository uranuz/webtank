module webtank.security.auth.core.controller;

import std.conv, std.digest.digest, std.datetime, std.utf, std.base64 : Base64URL;

import webtank.security.auth.iface.controller: IAuthController;


/// Класс управляет выдачей билетов для доступа
class AuthCoreController: IAuthController
{
	import webtank.security.auth.iface.user_identity: IUserIdentity;

	import webtank.security.auth.common.exception: AuthException;
	import webtank.security.auth.common.user_identity: CoreUserIdentity;
	import webtank.security.auth.common.session_id: SessionId, sessionIdStrLength;

	import webtank.net.http.input: HTTPInput;

	import webtank.db: IDatabase, queryParams, IDatabaseFactory;
	import webtank.security.auth.core.consts: sessionLifetime;
	import webtank.security.auth.core.utils: getAuthDB;

protected:
	IDatabaseFactory _dbFactory;

public:
	import std.exception: enforce;

	this(IDatabaseFactory factory)
	{
		enforce(factory !is null, `Expected instance of IDatabaseFactory`);
		_dbFactory = factory;
	}

	/// Выполняет HTTP-запроса по идентификатору сессии
	/// Возвращает удостоверение пользователя
	override IUserIdentity authenticate(HTTPInput req)
	{
		import std.conv: text;
		import webtank.net.http.headers.consts: HTTPHeader, CookieName;
		import webtank.datctrl.record_format: RecordFormat, PrimaryKey;
		import webtank.db.datctrl: getRecord;

		auto authDB = _dbFactory.getAuthDB();

		string SIDString = req.cookies.get(CookieName.SessionId, null);

		enforce!AuthException(SIDString.length > 0, `Empty sid string`);
		enforce!AuthException(SIDString.length == sessionIdStrLength, `Incorrect length of sid string`);

		SessionId sessionId;
		Base64URL.decode(SIDString, sessionId[]);

		enforce!AuthException(sessionId != SessionId.init, `Empty sid`);

		// По сессии узнаем информацию о пользователе
		auto userRec = authDB.queryParams(
`select
	su.num,
	su.email,
	su.login,
	su.name,
	to_json(coalesce(
		(
			select
				-- Роли пользователя
				array_agg(R.name) filter(
					where nullif(R.name, '') is not null
				)
			from user_access_role UR
			join access_role R
				on R.num = UR.role_num
			where
				UR.user_num = su.num
		), ARRAY[]::text[]
	)) "roles",
	ss.client_address,
	ss.user_agent
from(
	-- Находим сессию и проверяем, что она не "протухла"
	select
		sss.site_user_num,
		sss.client_address,
		sss.user_agent
	from session sss
	where
		sss.sid = $1::text
		and
		sss.created > (current_timestamp at time zone 'UTC' - ($2::text || ' minutes')::interval)
	limit 1
) ss
join site_user su
	on su.num = ss.site_user_num
limit 1`, Base64URL.encode(sessionId), sessionLifetime
		).getRecord(RecordFormat!(
			PrimaryKey!(size_t, "num"),
			string, "email",
			string, "login",
			string, "name",
			string[], "roles",
			string, `client_address`,
			string, `user_agent`
		)());

		//Проверяем адрес и клиентскую программу с имеющимися при создании сессии
		enforce!AuthException(
			req.headers.get(HTTPHeader.XRealIP, null) == userRec.getStr!`client_address`,
			`User IP-address mismatch`);
		enforce!AuthException(
			req.headers.get(HTTPHeader.UserAgent, null) == userRec.getStr!`user_agent`,
			`User agent mismatch`);

		string[string] userData = [
			"userNum": userRec.getStr!"num",
			"email": userRec.getStr!"email"
		];

		import std.array: join;
		//Получаем информацию о пользователе из результата запроса
		return new CoreUserIdentity(
			userRec.getStr!"login",
			userRec.getStr!"name",
			userRec.get!"roles",
			userData,
			sessionId
		);
	}

	void logout(IUserIdentity user)
	{
		import std.conv: to, ConvException;

		if( user is null ) {
			return;
		}
		scope(exit) {
			// В любом случае нужно вызвать инвалидацию удостоверения
			user.invalidate();
		}
		size_t userNum;
		try {
			userNum = user.data.get(`userNum`, null).to!size_t;
		} catch(ConvException e) {
			return;
		}

		// Сносим все сессии пользователя из базы
		_dbFactory.getAuthDB().queryParams(
			`delete from session where "site_user_num" = $1`, userNum);
	}
}
