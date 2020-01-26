module webtank.net.http.context;

class HTTPContext
{
	import webtank.net.http.handler.iface: IHTTPHandler;
	import webtank.security.right.user_rights: UserRights;
	import webtank.net.service.iface: IWebService;
	import webtank.net.server.iface: IWebServer;
	import webtank.net.http.input: HTTPInput;
	import webtank.net.http.output: HTTPOutput;
	import webtank.security.auth.iface.user_identity: IUserIdentity;
	import webtank.security.auth.common.anonymous_user: AnonymousUser;

public:
	this(HTTPInput req, HTTPOutput resp, IWebServer srv)
	{
		import std.exception: enforce, ifThrown;
		_request = req;
		_response = resp;
		_server = srv;

		// Проверяем, что все API работает
		enforce(request !is null, `Expected instance of HTTPInput`);
		enforce(response !is null, `Expected instance of HTTPOutput`);
		enforce(server !is null, `Expected instance of IWebServer`);
		enforce(service !is null, `Expected instance of IWebService`);
		enforce(service.accessController !is null, `Expected instance of IAuthController`);

		_userIdentity = ifThrown(service.accessController.authenticate(request), null);
		if( _userIdentity is null ) {
			_userIdentity = new AnonymousUser;
		}
		enforce(user !is null, `Expected instance of IUserIdentity`);
	}

	///Запрос к серверу по протоколу HTTP
	HTTPInput request() @property {
		return _request;
	}

	///Объект ответа сервера
	HTTPOutput response() @property {
		return _response;
	}

	///Экземпляр сервиса, с общими для процесса данными
	IWebService service() @property {
		return _server.service;
	}

	///Экземпляр объекта сервера, обслуживающего запросы
	IWebServer server() @property {
		return _server;
	}

	///Удостоверение пользователя
	IUserIdentity user() @property {
		return _userIdentity;
	}

	void user(IUserIdentity userIdentity) @property {
		_userIdentity = userIdentity;
	}

	UserRights rights() @property {
		return UserRights(this);
	}

	/++
	+ Помойка для хранения переменных уровня сессии, для которых не смогли найти место.
	+ Если что-то здесь лежит, то это скорее всего "бедное", либо "временное" техническое решение
	+/
	ref string[string] junk() @property {
		return _junk;
	}

	void _setCurrentHandler(IHTTPHandler handler) {
		_handlers ~= handler;
	}

	void _unsetCurrentHandler(IHTTPHandler handler)
	{
		import std.exception: enforce;
		import std.range: back, empty, popBack;
		enforce(!_handlers.empty, "HTTP handler list is empty!!!");
		enforce(handler is _handlers.back, "Mismatched current HTTP handler!!!");
		_handlers.popBack(); // drop handler from list
	}

	/// Текущий выполняемый обработчик для HTTP-запроса
	IHTTPHandler currentHandler() @property
	{
		import std.range: back, empty;
		return !_handlers.empty? _handlers.back: null;
	}

protected:
	HTTPInput _request;
	HTTPOutput _response;
	IWebServer _server;
	IUserIdentity _userIdentity;

	IHTTPHandler[] _handlers;
	string[string] _junk;
}