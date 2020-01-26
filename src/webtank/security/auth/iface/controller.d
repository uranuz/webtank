module webtank.security.auth.iface.controller;

import webtank.security.auth.iface.user_identity: IUserIdentity;
import webtank.net.http.input: HTTPInput;

///Интерфейс контролёра доступа пользователей к системе
interface IAuthController
{
	/// Метод пытается провести аутентификацию переданного запроса.
	/// Возвращает объект IUserIdentity, либо кидает исключение, если не вышло
	IUserIdentity authenticate(HTTPInput input);
}