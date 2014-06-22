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
	
	///Возвращает true, если разрешено выполнение действия action для ресурса resource. Иначе - false
	bool isActionAllowed( string resource, string action /+, string attribute +/);
	//bool isResourceGranted( string resource, string attribute );
	
// 	bool isAllowed(string resource, string action, string attribute = null);
// 	bool isResourceAccessAllowed(string resource, string attribute = null);
// 	bool isActionAccessAllowed(string access_control, string attribute = null);
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
		
		bool isActionAllowed( string resource, string action )
		{	return false; }
	}
}

///Интерфейс контролёра доступа пользователей к системе
interface IAccessController
{
	///Метод пытается провести аутентификацию по переданному объекту context
	///Возвращает объект IUserIdentity (удостоверение пользователя)
	IUserIdentity authenticate(Object context);
}
