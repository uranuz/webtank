module webtank.security.auth.iface.controller;

import webtank.security.auth.iface.user_identity: IUserIdentity;

///Интерфейс контролёра доступа пользователей к системе
interface IAuthController
{
	///Метод пытается провести аутентификацию по переданному объекту context
	///Возвращает объект IUserIdentity (удостоверение пользователя)
	IUserIdentity authenticate(Object context);
}