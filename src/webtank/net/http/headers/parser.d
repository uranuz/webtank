module webtank.net.http.headers.parser;

import webtank.net.http.headers.headers: HTTPHeaders, extractContentLength;

///HTTP headers parser
///Парсер HTTP заголовков
class HTTPHeadersParser
{
	import webtank.net.http.http: HTTPBadRequest;
	import webtank.net.http.headers.consts: HTTPHeader;

	this(string data) {
		feed(data);
	}

	this() {}

	///Append new data to interal buffer and parse them
 	///Добавление данных к внутреннему буферу и запуск их разбора
	void feed(string data)
	{
		_data ~= data;
		_splitLines();
		_parseLines();
	}

	///Restarts processing of string buffer passed to object
	///Перезапуск обработки строки переданной объекту
	void reprocess() @property
	{
		_partialClear();
		_splitLines();
		_parseLines();
	}

	///Returns true if HTTP starting line (with HTTP method, URI and version) was read or false otherwise
	///Возвращает true, если прочитана начальная строка (с HTTP-методом, URI и версией ). Иначе false
	bool isStartLineAccepted() @property {
		return _dataLines.length >= 1;
	}

	///Returns HTTPHeaders instance if headers were parsed correctly or null otherwise
	///Возвращает экземпляр HTTPHeaders если заголовки прочитаны верно или иначе null
	HTTPHeaders getHeaders()
	{
		if( _isEndReached )
			return new HTTPHeaders(_headers);
		else
			return null;
	}

	///Returns interal buffer data related to HTTP message body
	///Возвращает данные внутреннего буфера, относящиеся к телу HTTP-запроса
	string bodyData() @property
	{
		if( _isEndReached )
		{
			size_t bodyDataEndPos = _headersLength + this.contentLength;
			if( bodyDataEndPos < _data.length ) {
				return _data[_headersLength.. bodyDataEndPos];
			} else {
				return _data[_headersLength..$];
			}
		} else {
			return null;
		}
	}

	size_t contentLength() @property {
		return extractContentLength(_headers);
	}

	///Returns interal buffer data related to HTTP headers
	///Возвращает данные буфера, относящиеся к заголовкам HTTP-запроса
	string headerData() @property
	{
		import std.exception: enforce;
		enforce!HTTPBadRequest(_isEndReached, "Request headers buffer is too large or is empty or malformed!");
		return _data[0.._headersLength];
	}

	///Return true if end of headers reached or false otherwise
	///Возвращает true, если достигнут конец заголовков
	bool isEndReached() @property {
		return _isEndReached;
	}

	void clear()
	{
		_data = null;
		_partialClear();
	}

protected:
	void _splitLines()
	{
		if(_isEndReached)
			return; //Если заголовки уже закончились, то ничего не делаем

		for( ; _pos < _data.length; _pos++ )
		{
			// Разбираем строки по переносу
			// Поскольку срез берётся исключая последний элемент то условие на <=
			if( _pos+2 <= _data.length && _data[_pos.._pos+2] == "\r\n" ) 
			{
				_dataLines ~= _data[_currLineStart.._pos];
				_currLineStart = _pos + 2; //Начало текущей строки
				// Обнаруживаем конец заголовков
				if( _pos+4 <= _data.length && _data[_pos.._pos+4] == "\r\n\r\n" )
				{
					_currLineStart = _pos + 4; //Начало текущей строки
					_headersLength = _pos + 4;
					_isEndReached = true;
					break;
				}
			}
		}
	}

	void _parseLines()
	{
		import std.string;
		import std.array;
		import std.algorithm: startsWith;

		//Разбор заголовков
		foreach( n, var; _dataLines )
		{
			if( n == 0 )
			{
				//Разбираем первую строку
				auto startLineAttr = split(_dataLines[0], " ");

				if( startsWith( startLineAttr[0], "HTTP/" ) )
				{
					if( startLineAttr.length < 3 )
					{
						//Плохой запрос
						throw new HTTPBadRequest(
							"Status line of HTTP request must follow format: <http-version> <status-code> <reason-phrase>");
					}
					_headers[HTTPHeader.HTTPVersion] = [startLineAttr[0]];
					_headers[HTTPHeader.StatusCode] = [startLineAttr[1]];
					_headers[HTTPHeader.ReasonPhrase] = [startLineAttr[2..$].join(" ")];
				}
				else
				{
					if( startLineAttr.length != 3 )
					{
						//Плохой запрос
						throw new HTTPBadRequest(
							"Request line of HTTP request must consist of 3 sections: <method> <request-uri> <http-version>");
					}

					string HTTPMethod = toLower( strip( startLineAttr[0] ) );
					//TODO: Добавить проверку начальной строки
					//Проверить методы по списку
					//Проверить URI (не знаю как)
					//Проверить версию HTTP. Поддерживаем 1.0, 1.1 (0.9 фтопку)
					_headers[HTTPHeader.Method] = [startLineAttr[0]];
					_headers[HTTPHeader.RequestURI] = [startLineAttr[1]];
					_headers[HTTPHeader.HTTPVersion] = [startLineAttr[2]];
				}
			}
			else if( n > 0 )
			{
				bool isHeaderDelimFound = false;
				for( size_t j = 0; j < var.length; j++ )
				{	
					if( j+2 <= var.length && var[j..j+2] == ": " )
					{	
						// Названия заголовков храним без лишних пробелов в нижнем регистре,
						// а значения в том, в котором пришли
						isHeaderDelimFound = true;
						string headerName = var[0..j].strip().toLower();
						string headerValue = var[j+2..$];
						if( auto headerPtr = headerName in _headers ) {
							// Может быть несколько заголовков с одинаковым именем. Например, заголовки Cookie, Set-Cookie
							(*headerPtr) ~= headerValue;
						} else {
							_headers[headerName] = [headerValue];
						}
						break;
					}
				}
				if( !isHeaderDelimFound )
					throw new HTTPBadRequest(`Name-value delimiter ": " is not found in a header line`);
			}
		}
		_parsedLinesCount = _dataLines.length;
	}

	void _partialClear()
	{
		_dataLines = null;
		_pos = 0;
		_isEndReached = false;
		_headers = null;
		_headersLength = 0;
		_currLineStart = 0;
		_parsedLinesCount = 0;
	}

protected:
	string _data;
	string[] _dataLines;
	size_t _pos = 0;
	bool _isEndReached = false;
	size_t _headersLength;
	string[][string] _headers;
	size_t _currLineStart;
	size_t _parsedLinesCount = 0;
}