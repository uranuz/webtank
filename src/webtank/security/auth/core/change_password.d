module webtank.security.auth.core.change_password;

import webtank.db.iface.factory: IDatabaseFactory;

bool changeUserPassword(bool doPwCheck = true)(
	IDatabaseFactory dbFactory,
	string login,
	string oldPassword,
	string newPassword,
	bool useScr = false
) {
	import webtank.security.auth.core.crypto: makePasswordHashCompat, checkPassword;
	import webtank.security.auth.core.utils: getAuthDB;
	import webtank.security.auth.core.consts: minPasswordLength;
	import webtank.db.query_params: queryParams;

	import std.datetime: DateTime;
	// import mkk.logging: SiteLoger; TODO: Устаревшая вещь - нужно переделать

	// SiteLoger.info( `Проверка длины нового пароля`, `Смена пароля пользователя` );
	if( newPassword.length < minPasswordLength )
	{
		// SiteLoger.info( `Новый пароль слишком короткий`, `Смена пароля пользователя` );
		return false;
	}

	auto authDB = dbFactory.getAuthDB();

	// SiteLoger.info( `Подключаемся к базе данных аутентификации`, `Смена пароля пользователя` );
	// SiteLoger.info( `Получаем данные о пользователе из БД`, `Смена пароля пользователя` );
	auto userQueryRes = authDB.queryParams(
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
	auto changePwQueryRes = authDB.queryParams(
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
