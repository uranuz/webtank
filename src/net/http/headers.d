module webtank.net.http.headers;

import webtank.net.http.http;
//TODO: Подумать, нужно ли делать URI декодировку заголовков

///HTTP headers parser
///Парсер HTTP заголовков
class HTTPHeadersParser
{	
	this(string data)
	{	feed(data);
	}
	
	this() {}
	
	///Append new data to interal buffer and parse them
 	///Добавление данных к внутреннему буферу и запуск их разбора
	void feed(string data)
	{	_data ~= data;
		_splitLines();
		_parseLines();
	}

	///Restarts processing of string buffer passed to object
	///Перезапуск обработки строки переданной объекту
	void reprocess() @property
	{	_partialClear();
		_splitLines();
		_parseLines();
	}
	
	///Returns true if HTTP starting line (with HTTP method, URI and version) was read or false otherwise
	///Возвращает true, если прочитана начальная строка (с HTTP-методом, URI и версией ). Иначе false
	bool isStartLineAccepted() @property
	{	return _dataLines.length >= 1;
	}
	
	///Returns HTTPHeaders instance if headers were parsed correctly or null otherwise
	///Возвращает экземпляр HTTPHeaders если заголовки прочитаны верно или иначе null 
	HTTPHeaders getHeaders()
	{	if( _isEndReached ) 
			return new HTTPHeaders(_headers);
		else
			return null;
	}

	///Returns interal buffer data related to HTTP message body
	///Возвращает данные внутреннего буфера, относящиеся к телу HTTP-запроса
	string bodyData() @property
	{	if( _isEndReached ) 
			return _data[_headersLength..$];
		else
			return null;
	}
	
	///Returns interal buffer data related to HTTP headers
	///Возвращает данные буфера, относящиеся к заголовкам HTTP-запроса
	string headerData() @property
	{	if( _isEndReached )
			return _data[ 0.._headersLength ];
		else
			return null;
	}
	
	///Return true if end of headers reached or false otherwise
	///Возвращает true, если достигнут конец заголовков
	bool isEndReached() @property
	{	return _isEndReached;
	}
	
	void clear()
	{	_data = null;
		_partialClear();
	}
	
protected:
	void _splitLines()
	{	if(_isEndReached) 
			return; //Если заголовки уже закончились, то ничего не делаем
		
		for( ; _pos < _data.length; _pos++ )
		{	if( _pos+2 < _data.length )
			{	if( _data[_pos.._pos+2] == "\r\n" )  //Разбираем строки по переносу
				{	_dataLines ~= _data[_currLineStart.._pos];
					_currLineStart = _pos + 2; //Начало текущей строки
					if( _pos+4 < _data.length ) //Обнаруживаем конец заголовков
					{	if( _data[_pos.._pos+4] == "\r\n\r\n" )
						{	_headersLength = _pos + 4;
							_isEndReached = true;
							break;
						}
					}
				}
			}
		}
	}
	
	void _parseLines()
	{	//Разбор заголовков
		foreach( n, var; _dataLines[_parsedLinesCount..$] )
		{	import std.string;
			if( n == 1 )
			{	//Разбираем первую строку
				import std.array;
				auto startLineAttr = split(_dataLines[0], " ");
				if( startLineAttr.length == 3 )
				{	string HTTPMethod = toLower( strip( startLineAttr[0] ) );
					//TODO: Добавить проверку начальной строки
					//Проверить методы по списку
					//Проверить URI (не знаю как)
					//Проверить версию HTTP. Поддерживаем 1.0, 1.1 (0.9 фтопку)
					_headers["method"] = startLineAttr[0];
					_headers["request-uri"] = startLineAttr[1];
					_headers["http-version"] = startLineAttr[2];
				}
				else //Плохой запрос
				{	throw new HTTPException(
						"Starting line of HTTP request must consist of 3 sections separated by space symbols!!!",
						400 //400 Bad Request
					); 
				}
			}
			else if( n > 1 )
			{	bool isHeaderDelimFound = false;
				for( size_t j = 0; j < var.length; j++ )
				{	if( j+2 < var.length )
					{	if( var[j..j+2] == ": " )
						{	//Названия заголовков храним без лишних пробелов в нижнем регистре,
							//а значения в том, в котором пришли
							isHeaderDelimFound = true;
							_headers[ toLower( strip( var[0..j] ) ) ] = var[j+2..$];
							break;
						}
					}
				}
				if( !isHeaderDelimFound )
					throw new HTTPException(
						`Name-value delimiter ": " is not found in a header line!!!`,
						400 //400 Bad Request
					);
			}
		}
		_parsedLinesCount = _dataLines.length;
	}
	
	void _partialClear()
	{	_dataLines = null;
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
	string[string] _headers;
	size_t _currLineStart;
	size_t _parsedLinesCount = 0;
}

/// Class is representing HTTP headers for request and response
/// Класс, представляющий HTTP заголовки для запроса и ответа
class HTTPHeaders
{	
	///HTTP request headers constructor
	///Конструктор для заголовков запроса
	this(string[string] headers)
	{	_isRequest = true;
		_headers = headers.dup;
	}
	
	///HTTP response headers constructor
	///Конструктор заголовков ответа
	this()
	{	_isRequest = false;
		_headers["http-version"] = "HTTP/1.0";
		_headers["status-code"] = "200";
		_headers["reason-phrase"] = "OK";
	}
	
	///Method for getting status line of HTTP response
	///Метод для получения строки состояния HTTP ответа
	string getStatusLine()
	{	
		if( _isRequest ) //Для запроса нет статусной строки
			return null;
		else 
			return //Для ответа прописываем Status-Line
				_headers["http-version"] ~ " " 
				~ _headers["status-code"] ~ " "
				~ _headers.get("reason-phrase", "") ~ "\r\n";
	}
	
	///Method for getting HTTP headers as string (separated by "\r\n")
	///Метод для получения HTTP заголовков в виде строки (разделённых символами переноса "\r\n")
	string getString()
	{	string result;
		foreach( name, value; _headers )
		{	if( name == "http-version" || name == "status-code" || name == "reason-phrase")
				continue;
			result ~= name ~ ": " ~ value ~ "\r\n";
		}
		return result;
	}
	
	///Operator for writing value of header
	///Опреатор записи значения заголовка
	void opIndexAssign(string value, string name) 
	{	import std.string;
		if( strip( value ).length > 0 ) //Пустые значения не добавляем
			_headers[ toLower( strip( name ) ) ] = value;
	}
	
	///Operator for reading value of header
	///Оператор чтения значения заголовка
	string opIndex(string name)
	{	import std.string;
		return _headers.get( toLower( strip( name ) ), null );
	}
	
	///Method gets value of header with "name" or "defaultValue" if header is not exist
	///Метод получает значение заголовка с именем name или defaultValue, если заголовок отсутствует
	string get(string name, string defaultValue)
	{	import std.string;
		return _headers.get( toLower( strip( name ) ), defaultValue );
	}
	
	///Оператор in для класса
	inout(string)* opBinaryRight(string op)(string name) inout if(op == "in")
	{	return ( name in _headers );
	}
	
	///Response headers clear method
	///Очистка заголовков ответа
	void clear()
	{	if( !_isRequest )
			_headers = null;
	}
	
protected:
	string[string] _headers;
	bool _isRequest;
}

// void main()
// {	auto headers = new Headers;
// 	string headerStr = "GET / HTTP/1.1\r\nHost: translate.google.ru\r\nConnection: keep-alive\r\nCache-Control: max-age=0\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nUser-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36\r\nX-Chrome-Variations: COu1yQEIh7bJAQiptskBCJqEygEIqYXKAQi3hcoB\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: ru-RU,ru;q=0.8,en-US;q=0.6,en;q=0.4\r\n\r\n";
// 	headers.appendData(headerStr);
// 	headers.process();
// 	import std.stdio;
// 	writeln(headers._headers);
// }
