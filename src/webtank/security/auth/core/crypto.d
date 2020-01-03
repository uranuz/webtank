module webtank.security.auth.core.crypto;

import std.base64: Base64URL;
import std.conv: to;

import deimos.openssl.sha;
import webtank.security.auth.core.old.scrypt;
import webtank.security.auth.common.session_id;

enum uint pwHashScryptByteLength = 72; //Количество байт в хэше пароля

enum uint pwHashSha384ByteLength = 48; // Количество байт в хэше пароля SHA-384: 384 / 8 = 48

enum scryptN = 1024;
enum scryptR = 8;
enum scryptP = 1;

//Служебная функция для генерации Ид сессии
SessionId generateSessionId(const(char)[] login, const(char)[] rolesStr, const(char)[] dateString)
{
	auto idSource = login ~ "::" ~ dateString ~ "::" ~ rolesStr; //Создаём исходную строку
	SessionId sessionId;
	SHA384( cast(const(ubyte)*) idSource.ptr, idSource.length, sessionId.ptr );
	return sessionId; //Возвращаем идентификатор сессии
}

import std.datetime, std.random, core.thread;

///Генерирует хэш для пароля с "солью" и "перцем"
ubyte[] makeScryptPasswordHash(
	const(char)[] password,
	const(char)[] salt,
	const(char)[] pepper,
	size_t hashByteLength = pwHashScryptByteLength,
	ulong N = scryptN,
	uint r = scryptR,
	uint p = scryptP
) {
	ubyte[] pwHash = new ubyte[hashByteLength];

	auto secret = password ~ pepper;
	auto spice = pepper ~ salt;

	int result = crypto_scrypt(
		cast(const(ubyte)*) secret.ptr, secret.length,
		cast(const(ubyte)*) spice.ptr, spice.length,
		N, r, p, pwHash.ptr, hashByteLength
	);

	if( result != 0 )
		throw new Exception("Cannot make password hash!!!");

	return pwHash;
}

ubyte[] makePasswordHash(
	const(char)[] password,
	const(char)[] salt,
	const(char)[] pepper
) {
	// Создаем хэш первого уровня из самого пароля и соли
	ubyte[] passWithSalt = cast(ubyte[])(password ~ salt);
	ubyte[] innerHash = new ubyte[pwHashSha384ByteLength];
	SHA384( passWithSalt.ptr, passWithSalt.length, innerHash.ptr );

	// Создаем результирующий хэш из хэша первого уровня и "перца"
	ubyte[] innerHashWithPepper = cast(ubyte[])(innerHash ~ cast(ubyte[])(pepper));
	ubyte[] pwHash = new ubyte[pwHashSha384ByteLength];
	SHA384( innerHashWithPepper.ptr, innerHashWithPepper.length, pwHash.ptr );
	return pwHash;
}

///Кодирует хэш пароля для хранения в виде строки
string encodeScryptPasswordHash( const(ubyte[]) pwHash, ulong N = scryptN, uint r = scryptR, uint p = scryptP )
{
	return ( "scr$" ~ Base64URL.encode(pwHash) ~ "$" ~ pwHash.length.to!string
		~ "$" ~ N.to!string ~ "$" ~ r.to!string ~ "$" ~ p.to!string ).idup;
}

/// Кодирует хэш пароля для хранения в виде строки
string encodePasswordHash( const(ubyte[]) pwHash ) {
	return ("sha384$" ~ Base64URL.encode(pwHash)).idup;
}

import std.typecons: Tuple;
Tuple!(
	ubyte[], `pwHash`,
	string, `pwHashStr`
)
makePasswordHashCompat(
	const(char)[] password,
	const(char)[] salt,
	const(char)[] pepper,
	bool useScr = false
) {
	typeof(return) res;

	if( useScr )
	{
		res.pwHash = makeScryptPasswordHash(password, salt, pepper);
		res.pwHashStr = encodeScryptPasswordHash(res.pwHash);
	}
	else
	{
		res.pwHash = makePasswordHash(password, salt, pepper);
		res.pwHashStr = encodePasswordHash(res.pwHash);
	}
	return res;
}


bool checkPassword(
	const(char)[] encodedPwHash,
	const(char)[] password,
	const(char)[] salt,
	const(char)[] pepper
) {
	return checkPasswordExt(encodedPwHash, password, salt, pepper).checkResult;
}

///Проверяет пароль на соответствие закодированному хэшу с заданной солью и перцем
Tuple!(
	bool, `checkResult`,
	bool, `isOldHash`
)
checkPasswordExt(
	const(char)[] encodedPwHash,
	const(char)[] password,
	const(char)[] salt,
	const(char)[] pepper
) {
	import std.conv: to;
	import std.array: split;
	auto res = typeof(return)(false, false);

	auto params = encodedPwHash.split("$");

	// Ожидаем по крайней мере тип хэша и его значение
	if( params.length < 2 )
		return res;

	// По соглашению в 0 элементе хранится условный идентификатор типа хэша, а в 1 - сам хэш в Base64URL
	ubyte[] pwHash = Base64URL.decode(params[1]);
	switch( params[0] )
	{
		case "sha384":
		{
			// Текущий формат хэша пароля
			if( params.length != 2 )
				break;

			res.checkResult = pwHash == makePasswordHash(password, salt, pepper);
			break;
		}
		case "scr":
		{
			// Старый формат хэша пароля
			if( params.length != 6 )
				break;

			size_t hashLen = params[2].to!size_t;
			ulong scryptN = params[3].to!ulong;
			uint scryptR = params[4].to!uint;
			uint scryptP = params[5].to!uint;

			if( hashLen != pwHash.length )
				break;

			res.checkResult = pwHash == makeScryptPasswordHash(
				password, salt, pepper, hashLen,
				scryptN, scryptR, scryptP
			);
			// Хэш старый и его надо "апгрейдить"
			res.isOldHash = true;
			break;
		}
		default: break;
	}
	return res;
}