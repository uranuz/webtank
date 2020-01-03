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

public:
	this(HTTPInput request, HTTPOutput response, IWebServer server)
	{
		import std.exception: enforce;
		enforce(request, `Expected instance of HTTPInput`);
		enforce(response, `Expected instance of HTTPOutput`);
		enforce(server, `Expected instance of IWebServer`);
		_request = request;
		_response = response;
		_server = server;
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
	IUserIdentity user() @property
	{
		if( _userIdentity is null && service.accessController !is null ) {
			_userIdentity = service.accessController.authenticate(this);
		}
		return _userIdentity;
	}

	void user(IUserIdentity userIdentity) @property
	{
		import std.exception: enforce;
		enforce(userIdentity !is null, `User identity must not be null`);
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
		_handlerList ~= handler;
	}

	void _unsetCurrentHandler(IHTTPHandler handler)
	{
		if( _handlerList.length > 0 )
		{	if( handler is _handlerList[$-1] )
				_handlerList.length--;
			else
				throw new Exception("Mismatched current HTTP handler!!!");
		}
		else
			throw new Exception("HTTP handler list is empty!!!");
	}

	///Текущий выполняемый обработчик для HTTP-запроса
	IHTTPHandler currentHandler() @property {
		return _handlerList.length > 0? _handlerList[$-1]: null;
	}

	///Предыдущий обработчик HTTP-запроса
	IHTTPHandler previousHandler() @property {
		return _handlerList.length > 1? _handlerList[$-2]: null;
	}

protected:
	HTTPInput _request;
	HTTPOutput _response;
	IWebServer _server;
	IUserIdentity _userIdentity;

	IHTTPHandler[] _handlerList;
	string[string] _junk;
}