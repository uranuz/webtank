module webtank.net.web_form;

import std.range, std.ascii, std.conv;

import webtank.net.uri: decodeURIFormQuery;

// pop char from input range, or throw
private dchar popChar(T)(ref T input)
{
	dchar result = input.front;
	input.popFront();
	return result;
}

///Функция выполняет разбор данных HTML формы
T[][T] parseFormData(T)(T input)
{
	T[][T] result;
	T[] params = split(input, "&");

	foreach( param; params )
	{
		size_t count = 0;
		auto temp = param.save();
		for( ; !temp.empty; count++ )
		{
			if( popChar(temp) == '=' )
				break;
		}
		auto name = param.take(count).to!T;
		result[name] ~= temp;
	}

	return result;
}

interface IFormData
{
	string opIndex(string name) const;
	string[] keys() @property const;
	string[] values() @property const;
	string[] array(string name) @property const;
	string get(string name, string defValue);
	int opApply(int delegate(ref string value) del);
	int opApply(int delegate(ref string name, ref string value) del);
	int opApply(int delegate(ref string name, string[] values) del);
	inout(string)* opIn_r(string name) inout;
	string toString();
}

///Объект с интерфейсом, подобным ассоциативному массиву для хранения данных HTML формы
class FormData: IFormData
{
private:
	string[][string] _data;

public:
	this( ref string[][string] data ) {
		_data = data;
	}

	this( string formDataStr ) {
		_data = extractFormData( formDataStr );
	}

override {
	string opIndex(string name) const {
		return _data[name][0];
	}

	string[] keys() @property const
	{
		string[] result;
		foreach( name, ref array; _data )
			result ~= name;
		return result;
	}

	string[] values() @property const
	{
		string[] result;
		foreach( ref array; _data )
			result ~= array[0];
		return result;
	}

	string[] array(string name) @property const {
		return _data.get(name, null).dup;
	}

	string get(string name, string defValue) const
	{
		if( name in _data )
			return _data[name][0];
		else
			return defValue;
	}

	int opApply(int delegate(ref string value) del) //const
	{
		foreach( ref array; _data ) {
			if( auto ret = del(array[0]) )
				return ret;
		}
		return 0;
	}

	int opApply(int delegate(ref string name, ref string value) del) //const
	{
		foreach( name, ref array; _data ) {
			if( auto ret = del(name, array[0]) )
				return ret;
		}
		return 0;
	}

	int opApply(int delegate(ref string name, string[] values) del) //const
	{
		foreach( name, ref array; _data ) {
			if( auto ret = del(name, array) )
				return ret;
		}
		return 0;
	}

	inout(string)* opIn_r(string name) inout
	{
		auto array = name in _data;
		if( array )
			return &(*array)[0];
		else
			return null;
	}

	string toString()
	{
		import std.conv;
		return _data.to!string;
	}
} // override

}

class AggregateFormData: IFormData
{
private:
	IFormData _queryForm;
	IFormData _bodyForm;
public:
	this(IFormData queryForm, IFormData bodyForm)
	{
		_queryForm = queryForm;
		_bodyForm = _bodyForm;
		assert(_queryForm, `_queryForm is null`);
		assert(_bodyForm, `_bodyForm is null`);
	}

override {
	string opIndex(string name) const
	{
		if( auto val = name in _queryForm )
			return *val;
		else
			return _bodyForm[name];
	}

	string[] keys() @property const
	{
		import std.range: chain;
		import std.array: array;
		import std.algorithm: uniq;
		return chain(_queryForm.keys, _bodyForm.keys).uniq.array;
	}

	string[] values() @property const
	{
		string[] result;
		foreach( key; this.keys )
		{
			if( auto val = key in _queryForm ) {
				result ~= *val;
			} else if( auto val = key in _bodyForm ) {
				result ~= *val;
			}
		}
		return result;
	}

	string[] array(string name) @property const
	{
		if( name in _queryForm )
			return _queryForm.array(name);
		else
			return _bodyForm.array(name);
	}

	string get(string name, string defValue) const
	{
		if( auto val = name in _queryForm ) {
			return *val;
		} else if( auto val = name in _bodyForm ) {
			return *val;
		}
		return defValue;
	}

	int opApply(int delegate(ref string value) del) //const
	{
		foreach( key; this.keys )
		{
			if( auto val = key in _queryForm )
			{
				if( auto ret = del(*val) )
					return ret;
			} else if( auto val = key in _bodyForm ) {
				if( auto ret = del(*val) )
					return ret;
			}
		}
		return 0;
	}

	int opApply(int delegate(ref string name, ref string value) del) //const
	{
		foreach( key; this.keys )
		{
			if( auto val = key in _queryForm )
			{
				if( auto ret = del(key, *val) )
					return ret;
			} else if( auto val = key in _bodyForm ) {
				if( auto ret = del(key, *val) )
					return ret;
			}
		}
		return 0;
	}

	int opApply(int delegate(ref string name, string[] values) del) //const
	{
		foreach( key; this.keys )
		{
			if( key in _queryForm )
			{
				if( auto ret = del(key, _queryForm.array(key)) )
					return ret;
			} else if( key in _bodyForm ) {
				if( auto ret = del(key, _bodyForm.array(key)) )
					return ret;
			}
		}
		return 0;
	}

	inout(string)* opIn_r(string name) inout
	{
		if( auto val = name in _queryForm )
			return val;
		else
			return name in _bodyForm;
	}

	string toString()
	{
		import std.conv;
		string[][string] data;
		foreach( string key, string[] vals; this ) {
			data[key] = vals;
		}
		return data.to!string;
	}

} // override


}

///Функция выполняет разбор и декодирование данных HTML формы
string[][string] extractFormData(string queryStr)
{
	string[][string] result;
	foreach( key, values; parseFormData(queryStr) )
	{
		// TODO: Возможно, что данные сюда уже придут декодированными. Нужно обработать этот случай!
		string decodedKey = decodeURIFormQuery(key);
		foreach( val; values )
			result[decodedKey] ~= decodeURIFormQuery(val);
	}
	return result;
}