module webtank.security.right.common;

// Аттрибут указания доступа к объекту
struct RightObjAttr
{
	string name;
}

// Получить полное название объекта доступа, склеенного из частей
// Указанных через аттрибуты RightObjAttr
string GetSymbolAccessObject(alias Struc, string field)()
{
	import std.traits: getUDAs;
	string result;
	bool hasEmptyName = false;
	foreach( attr; getUDAs!(__traits(getMember, Struc, field), RightObjAttr) )
	{
		if( attr.name.length == 0 )
		{
			hasEmptyName = true;
			continue;
		}

		if( result.length > 0) result ~= `.`;
		result ~= attr.name;
	}
	if( hasEmptyName ) {
		if( result.length > 0) result ~= `.`;
		result ~= __traits(identifier, __traits(getMember, Struc, field));
	}
	return result;
}

import std.meta: AliasSeq;
import std.json: JSONValue;
import std.variant: Algebraic;
import webtank.datctrl.iface.record: IBaseRecord;

version(Have_ivy)
{
	import ivy.interpreter.data_node: IvyData;
	alias RightDataTypes = AliasSeq!(JSONValue, IBaseRecord, IvyData);
} else {
	alias RightDataTypes = AliasSeq!(JSONValue, IBaseRecord);
}

alias RightDataVariant = Algebraic!(RightDataTypes);