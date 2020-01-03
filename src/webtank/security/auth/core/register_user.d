module webtank.security.auth.core.register_user;

import std.datetime: DateTime;
import std.algorithm: endsWith;
import std.uuid: randomUUID;

import webtank.security.auth.core.controller: minLoginLength, minPasswordLength;
import webtank.security.auth.core.crypto: makePasswordHashCompat;
import webtank.common.conv: fromPGTimestamp;
import webtank.net.utils: PGEscapeStr;
import webtank.db.datctrl_joint: getRecordSet;
import webtank.db.database: queryParams;
import webtank.datctrl.record_format: RecordFormat, PrimaryKey, Writeable;
import std.typecons: Tuple;
import std.uuid: randomUUID, sha1UUID, UUID;

alias RegUserResult = Tuple!(size_t, `userNum`, UUID, `confirmUUID`);

// useScr = true использовать старый формат, оставлено для отладки возможных проблем совместимости
RegUserResult registerUser(alias getAuthDB)(
	string login,
	string password,
	string name,
	string email,
	bool useScr = false
) {
	import std.utf: count;
	import std.conv: text;
	import std.exception: enforce;
	import std.range: empty;

	enforce(!login.empty, `Не задан логин пользователя`);
	enforce(
		login.count >= minLoginLength,
		"Длина логина меньше минимально допустимой (" ~ minLoginLength.text ~ " символов)");

	if(
		getAuthDB().queryParams(
			`select 1 from site_user where login = $1 limit 1`, login
		).recordCount != 0
	) {
		throw new Exception("Пользователь с заданным логином уже зарегистрирован");
	}

	enforce(!name.empty, `Не задано имя пользователя`);
	enforce(
		name.count >= minLoginLength,
		"Длина имени пользователя меньше минимально допустимой (" ~ minLoginLength.text ~ " символов)");

	enforce(!password.empty, `Не задан пароль пользователя`);
	enforce(
		password.count >= minPasswordLength,
		"Длина пароля меньше минимально допустимой (" ~ minPasswordLength.text ~ " символов)");

	checkEmailAddress(email);

	static immutable addUserResultFmt = RecordFormat!(
		PrimaryKey!(size_t, "num"),
		string, "status",
		DateTime, "regTimestamp"
	)();

	// Генерируем UUID, который используется для ссылки подтверждения email
	UUID confirmUUID = sha1UUID(randomUUID().toString(), sha1UUID(login));
	string email_confirm_uuid = confirmUUID.toString();

	import std.array: join;
	string[] fieldNames;
	string[] fieldValues;
	static foreach( field; [`login`, `name`, `email`, `email_confirm_uuid`] )
	{
		fieldNames ~= field;
		mixin(`fieldValues ~= "'" ~ PGEscapeStr(` ~ field ~ `) ~ "'";`);
	}
	
	fieldNames ~= `reg_timestamp`;
	fieldValues ~= `current_timestamp at time zone 'UTC'`;

	// Сначала устанавливаем общую информацию о пользователе,
	// и заставляем БД саму установить дату регистрации, чтобы не иметь проблем с временными зонами
	auto addUserResult = getAuthDB().query(
		`insert into site_user (` ~ fieldNames.join(`, `) ~ `) `
		~ ` values(` ~ fieldValues.join(`, `) ~ `) `
		~ ` returning num, 'user added' "status", reg_timestamp`
	).getRecordSet(addUserResultFmt);

	if( addUserResult.length != 1 || addUserResult.front.get!"status"() != `user added` ) {
		throw new Exception(`При сохранении информации о пользователе произошла ошибка`);
	}

	// Генерируем случайную соль для пароля, и используем дату регистрации из базы для сотворения хэша пароля
	string pwSaltStr = randomUUID().toString();
	string pwPepperStr = addUserResult.front.get!"regTimestamp"().toISOExtString();
	auto hashRes = makePasswordHashCompat(password, pwSaltStr, pwPepperStr, useScr);

	// Прописываем хэш пароля в БД
	auto setPasswordResult = getAuthDB().queryParams(
`update site_user set pw_hash = $1, pw_salt = $2
where num = $3
returning num, 'user upd' "status", reg_timestamp`,
		hashRes.pwHashStr, pwSaltStr, addUserResult.front.get!"num"()
	).getRecordSet(addUserResultFmt);

	if( setPasswordResult.length != 1 || setPasswordResult.front.get!"status"() != `user upd` ) {
		throw new Exception(`Произошла ошибка при завершении сохранения информации о пользователе`);
	}

	// Возвращаем идентификатор нового пользователя народу
	return RegUserResult(setPasswordResult.front.get!"num"(), confirmUUID);
}

void checkEmailAddress(string emailAddress)
{
	import std.range: empty;
	import std.algorithm: canFind;
	import std.exception: enforce;
	enforce(!emailAddress.empty, `Адрес электронной почты не должен быть пустым`);
	// Почему 5?: a@b.c
	enforce(emailAddress.canFind('@') && emailAddress.length >= 5, `Некорректный адрес электронной почты`);
}

void addUserRoles(alias getAuthDB)(size_t userId, string[] roles, bool overwrite = false)
{
	import std.algorithm: map;
	import std.array: join;
	import std.conv: text;
	// При установке флага на перезапись ролей пользователя (overwrite)
	// будет добавлен подзапрос на удаление связей пользователя с ролями не из переданного списка.
	// Если флаг не установлен то будут назначены роли, к которым пользователь не был привязан.
	// Роль в любом случае должна уже существовать, она не будет добавлена автоматически (добавляются только связи)
	immutable string deleteDataQuery = `,
	for_delete as(
		select ua_role.num
		from user_access_role ua_role
		left join access_role a_role
			on a_role.num = ua_role.role_num
		left join rolz rlz
			on rlz.rol = a_role.name
		where ua_role.num = ` ~ userId.text ~ ` and(a_role.num is null or rlz.rol is null)
	)`;
	static immutable string deleteQuery = `union all
	delete from user_access_role as new_ua_role
	where new_ua_role.num in (select num from for_delete)
	returning new_ua_role.num, 'delete' status`;

	getAuthDB().query(`
	with rolz(rol) as(
		select unnest(ARRAY[` ~ roles.map!( (it) => "'" ~ PGEscapeStr(it) ~ "'" ).join(", ") ~ `]::text[])
	),
	for_insert as(
		select ` ~ userId.text ~ ` user_num, a_role.num role_num
		from rolz
		join access_role a_role
			on rolz.rol = a_role.name
		left join user_access_role ua_role
			on ua_role.user_num = ` ~ userId.text ~ ` and ua_role.role_num = a_role.num
		where ua_role.num is null
	)`~ (overwrite? deleteDataQuery: null) ~`
	insert into user_access_role as new_ua_role (user_num, role_num)
	select * from for_insert
	returning new_ua_role.num, 'insert' status
	` ~ (overwrite? deleteQuery: null));
}
