module webtank.net.http.context;

import webtank.net.http.request, webtank.net.http.response, webtank.security.access_control, webtank.net.http.handler;

class HTTPContext
{	
	this(ServerRequest rq, ServerResponse rp)
	{	_request = rq;
		_response = rp;
	}
	///Запрос к серверу по протоколу HTTP
	ServerRequest request() @property
	{	return _request; }
	
	///Объект ответа сервера
	ServerResponse response() @property
	{	return _response; }
	
	///Удостоверение пользователя
	IUserIdentity user() @property
	{	return _userIdentity; }
	
	void _setuser(IUserIdentity newIdentity) 
	{	if( _userIdentity is null )
			_userIdentity = newIdentity;
		else
			throw new Exception("Access ticket for connection is already set!!!");
	}

	void _setCurrentHandler(IHTTPHandler handler)
	{	_handlerList ~= handler;
	}

	void _unsetCurrentHandler(IHTTPHandler handler)
	{	if( _handlerList.length > 0 )
		{	if( handler is _handlerList[$-1] )
				_handlerList.length--;
			else
				throw new Exception("Mismatched current HTTP handler!!!");
		}
		else
			throw new Exception("HTTP handler list is empty!!!");
	}

	///Текущий выполняемый обработчик для HTTP-запроса
	IHTTPHandler currentHandler() @property
	{	return _handlerList.length > 0 ? _handlerList[$-1] : null;
	}

	///Предыдущий обработчик HTTP-запроса
	IHTTPHandler previousHandler() @property
	{	return _handlerList.length > 1 ? _handlerList[$-2] : null;
	}
	
protected:
	ServerRequest _request;
	ServerResponse _response;
	IUserIdentity _userIdentity;

	IHTTPHandler[] _handlerList;
}