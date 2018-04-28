module webtank.net.http.context;

import webtank.net.http.input, webtank.net.http.output, webtank.security.access_control, webtank.net.http.handler;

import webtank.security.right.current: CurrentUserRights;

class HTTPContext
{
	this(HTTPInput request, HTTPOutput response)
	{
		_request = request;
		_response = response;
	}

	///Запрос к серверу по протоколу HTTP
	HTTPInput request() @property {
		return _request;
	}

	///Объект ответа сервера
	HTTPOutput response() @property {
		return _response;
	}

	///Удостоверение пользователя
	IUserIdentity user() @property {
		return _userIdentity;
	}

	CurrentUserRight rights() @property {
		return _rights;
	}

	void _setuser(IUserIdentity newIdentity)
	{
		if( _userIdentity is null )
			_userIdentity = newIdentity;
		else
			throw new Exception("Access ticket for connection is already set!!!");
	}

	void _setCurrentHandler(IHTTPHandler handler) {
		_handlerList ~= handler;
	}

	void _setRights(CurrentUserRights rgh)
	{
		import std.exception: enforce;
		enforce(_rights in null, `Cannot rewrite rights!!!`);
		_rights = rgh;
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
	IUserIdentity _userIdentity;
	CurrentUserRights _rights;

	IHTTPHandler[] _handlerList;
}