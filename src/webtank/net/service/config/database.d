module webtank.net.service.config.database;

import std.json: JSONValue;

string[string] getServiceDatabases(JSONValue jsonCurrService)
{
	//Вытаскиваем информацию об используемых базах данных
	JSONValue jsonDatabases;
	if( "databases" in jsonCurrService ) {
		jsonDatabases = jsonCurrService["databases"];
	}

	return resolveConfigDatabases(jsonDatabases);
}

string[string] resolveConfigDatabases(JSONValue jsonDatabases)
{
	import std.conv: text;
	import std.string: strip;
	import std.array: replace;
	import std.exception: enforce;
	import std.json: JSONType;
	import std.algorithm: canFind;

	string[string] result;
	if( jsonDatabases.type == JSONType.null_ )
		return result;

	enforce(
		jsonDatabases.type == JSONType.object,
		`Config section databases JSON value must be an object or null!!!`);

	
	foreach( string dbCaption, jsonDb; jsonDatabases )
	{
		string connStr;
		static immutable stringOnlyParams = [
			"dbname", "host", "user", "password"
		];

		foreach( string param, ref JSONValue jValue; jsonDb )
		{
			string value;
			if( stringOnlyParams.canFind(param) )
			{
				if( jValue.type == JSONType.string ) {
					value = jValue.str;
				} else {
					throw new Exception(`Expected string as value of database param: ` ~ param ~ ` for DB with id: ` ~ dbCaption);
				}
			}

			if( param == "port" )
			{
				switch(jValue.type)
				{
					case JSONType.string: value = jValue.str; break;
					case JSONType.uinteger: value = jValue.uinteger.text; break;
					case JSONType.integer: value = jValue.integer.text; break;
					default:
						throw new Exception(`Unexpected type of value for param: ` ~ param ~ ` for DB with id: ` ~ dbCaption);
				}
			}

			if( value.length )
			{
				if( connStr.length )
					connStr ~= ` `;
				connStr ~= param ~ "='" ~ value.replace(`'`, `\'`) ~ "'";
			}
		}
		result[dbCaption] = strip(connStr);
	}

	return result;
}
