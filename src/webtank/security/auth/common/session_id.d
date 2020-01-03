module webtank.security.auth.common.session_id;

enum uint sessionIdByteLength = 48; //Количество байт в ИД - сессии
enum uint sessionIdStrLength = sessionIdByteLength * 8 / 6;  //Длина в символах в виде base64 - строки
alias SessionId = ubyte[sessionIdByteLength]; //Тип: ИД сессии