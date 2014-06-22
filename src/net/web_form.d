module webtank.net.web_form;

import std.range, std.ascii, std.conv;

import webtank.net.uri;

// pop char from input range, or throw
private dchar popChar(T)(ref T input)
{	dchar result = input.front;
	input.popFront();
	return result;
}

///Функция выполняет разбор данных HTML формы
T[][T] parseFormData(T)(T input)
{	T[][T] result;
	T[] params = split(input, "&");

	foreach( param; params )
	{	size_t count = 0;
		auto temp = param.save();
		for( ; !temp.empty; count++ )
		{	if( popChar(temp) == '=' )
				break;
		}
		auto name = param.take(count).to!T;
		result[name] ~= temp;
	}

	return result;
}

///Объект с интерфейсом, подобным ассоциативному массиву для хранения
///данных HTML формы
class FormData
{
private:
	string[][string] _data;

public:
	this( ref string[][string] data )
	{	_data = data;
	}

	this( string formDataStr )
	{	_data = extractFormData( formDataStr );
	}

	string opIndex(string name) const
	{	return _data[name][0];
	}

	string[] keys() @property const
	{	string[] result;
		foreach( ref array; _data )
			result ~= array[0];
		return result;
	}

	string[] values() @property const
	{	string[] result;
		foreach( name, ref array; _data )
			result ~= name;
		return result;
	}

	string[] array(string name) @property const
	{	return _data[name].dup;
	}

	string get(string name, string defValue) const
	{	if( name in _data )
			return _data[name][0];
		else
			return defValue;
	}

	int opApply(int delegate(ref string value) del) //const
	{
		foreach( ref array; _data )
			if( auto ret = del( array[0] ) )
				return ret;
		return 0;
	}

	int opApply(int delegate(ref string name, ref string value) del) //const
	{
		foreach( name, ref array; _data )
			if( auto ret = del( name, array[0] ) )
				return ret;
		return 0;
	}

	auto opBinaryRight(string op)(string name) const
		if( op == "in" )
	{	auto array = name in _data;
		if( array )
			return &(*array)[0];
		else
			return null;
	}

	override string toString()
	{	import std.conv;
		return _data.to!string;
	}
	
}

///Функция выполняет разбор и декодирование данных HTML формы
string[][string] extractFormData(string queryStr)
{	string[][string] result;
	foreach( key, values; parseFormData(queryStr) )
	{	string decodedKey = decodeURIFormQuery(key);
		foreach( val; values )
			result[ decodedKey ] ~= decodeURIFormQuery(val);
	}
	return result;
}