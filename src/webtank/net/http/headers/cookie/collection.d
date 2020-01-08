module webtank.net.http.headers.cookie.collection;

///Набор HTTP Cookie
class CookieCollection
{
	import core.exception : RangeError;
	import webtank.net.http.headers.cookie.cookie: Cookie;

protected:
	Cookie[] _cookies;

public:
	this() {}

	this(Cookie[] cookies) pure {
		fill(cookies);
	}

	void fill(Cookie[] cookies) pure {
		_cookies = cookies;
	}

	///Оператор для установки cookie с именем name значения value
	///Создает новое Cookie, если не существует, или заменяет значение существующего
	void opIndexAssign( string value, string name ) nothrow
	{
		auto cookie = name in this;
		if( cookie )
			cookie.value = value;
		else
			_cookies ~= Cookie(name, value);
	}

	///Оператор для установки cookie с помощью структуры Cookie.
	///Добавлет новый элемент Cookie или заменяет существующий элемент,
	///если существует элемент с таким же именем Cookie.name
	void opOpAssign(string op)( Cookie value ) nothrow
		if( op == "~" ) 
	{
		auto cookie = value.name in this;
		if( cookie )
			*cookie = value;
		else
			_cookies ~= value;
	}

	///Оператор получения доступа к Cookie по имени
	///Бросает исключение RangeError, если Cookie не существует
	ref inout(Cookie) opIndex(string name) inout
	{
		auto cookie = name in this;
		if( cookie is null )
			throw new RangeError("Non-existent cookie: " ~ name);

		return *cookie;
	}

	///Оператор in для CookieCollection
	inout(Cookie)* opBinaryRight(string op)(string name) inout
		if( op == "in" )
	{
		foreach( i, ref c; _cookies )
		{
			if( c.name == name )
				return &_cookies[i];
		}
		return null;
	}

	/// Возвращает значение куки с именем name, если оно существует в наборе.
	/// Иначе возвращает переданное значение defValue
	string get(string name, string defValue = null) inout
	{
		if( auto cookiePtr = name in this )
			return cookiePtr.value;
		
		return defValue;
	}

	int opApply(scope int delegate(ref Cookie) dg)
	{
		int result = 0;
		for( int i = 0; i < _cookies.length; i++ )
		{
			result = dg( _cookies[i] );
			if( result )
				break;
		}
		return result;
	}

	override string toString()
	{
		import std.string: join;
		return toStringArray().join("\r\n");
	}

	string toOneLineString() inout
	{
		import std.string: join;
		return toStringArray().join("; ");
	}

	inout(string[]) toStringArray() inout
	{
		
		inout(string)[] cookieArr;
		foreach( cook; _cookies ) {
			cookieArr ~= cook.toString();
		}
		return cast(inout) cookieArr;
	}

	size_t length() @property {
		return _cookies.length;
	}

	void clear() {
		_cookies = null;
	}
}