module webtank.security.auth.iface.user_identity;

///Интерфейс удостоверения пользователя
interface IUserIdentity
{
	///Используемый тип проверки подлинности
	//string authenticationType() @property;
	
	//IAuthController accessController() @property;
	
	///Строка, содержащая некий идентификатор пользователя.
	///Может быть ключом записи пользователя в БД, login'ом, токеном при
	///аутентификации у внешнего поставщика проверки доступа (напр. соц. сети),
	///номером сертификата (при SSL/TLS аутентификации) и т.п.
	string id() @property;
	
	///Читаемое имя человека, название организации или автоматизированного клиента
	string name() @property;
	
	///Словарь с доп. информацией связаной с пользователями
	string[string] data() @property;
	
	///Возвращает true, если пользователь успешно прошёл аутентификацию. Иначе - false
	bool isAuthenticated() @property;
	
	///Функция возвращает true, если пользователь выступает в роли roleName
	bool isInRole(string roleName);

	///Делает текущий экземпляр удостоверения пользователя недействительным
	///После этого методы isAuthenticated, isInRole и т.п. должны
	///возвращать, не позволяя выполнять какие-либо действия на уровне прав.
	void invalidate();
}