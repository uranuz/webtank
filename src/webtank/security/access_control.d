module webtank.security.access_control;

///Интерфейс удостоверения пользователя
interface IUserIdentity
{
	///Используемый тип проверки подлинности
	//string authenticationType() @property;
	
	//IAccessController accessController() @property;
	
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

///Класс представляет удостоверение анонимного пользователя
class AnonymousUser: IUserIdentity
{
public:
	override {
		string id()
		{	return null; }
		
		string name()
		{	return null; }
		
		string[string] data()
		{	return null; }
		
		bool isAuthenticated()
		{	return false; }
		
		bool isInRole(string roleName)
		{	return false; }

		void invalidate() {}
	}
}

///Интерфейс контролёра доступа пользователей к системе
interface IAccessController
{
	///Метод пытается провести аутентификацию по переданному объекту context
	///Возвращает объект IUserIdentity (удостоверение пользователя)
	IUserIdentity authenticate(Object context);
}
