module webtank.net.http.context;

import webtank.net.http.input, webtank.net.http.output, webtank.security.access_control, webtank.net.http.handler;

import webtank.security.right.user_rights: UserRights;
import webtank.net.service.iface: IWebService;
import webtank.net.server.iface: IWebServer;

class HTTPContext
{
	this(HTTPInput request, HTTPOutput response, IWebService service, IWebServer server)
	{
		_request = request;
		_response = response;
		_service = service;
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
		return _service;
	}

	///Экземпляр объекта сервера, обслуживающего запросы
	IWebServer server() @property {
		return _server;
	}

	///Удостоверение пользователя
	IUserIdentity user() @property
	{
		if( _userIdentity is null && _service.accessController !is null ) {
			_userIdentity = _service.accessController.authenticate(this);
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
	IWebService _service;
	IWebServer _server;
	IUserIdentity _userIdentity;

	IHTTPHandler[] _handlerList;
}