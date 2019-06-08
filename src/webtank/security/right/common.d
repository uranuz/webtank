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


import webtank.net.http.context: HTTPContext;
private void _checkItemRights(DataStruct, string fieldName)(HTTPContext ctx, string accessKind)
{
	import mkk.security.common.exception: SecurityException;
	import webtank.security.right.common: GetSymbolAccessObject;
	import std.exception: enforce;
	string accessObj = GetSymbolAccessObject!(DataStruct, fieldName)();
	enforce!SecurityException(
		ctx.rights.hasRight(accessObj, accessKind),
		`Недостаточно прав для редактирования поля: ` ~ fieldName);
}

void checkStructEditRights(DataStruct)(auto ref DataStruct record, HTTPContext ctx, string accessKind = `edit`)
{
	import mkk.security.common.exception: SecurityException;
	import webtank.security.right.common: RightObjAttr;
	import std.meta: AliasSeq;
	import std.traits: getUDAs;
	import webtank.common.optional: isUndefable;
	foreach( fieldName; AliasSeq!(__traits(allMembers, DataStruct)) )
	{
		alias FieldType = typeof(__traits(getMember, record, fieldName));
		alias RightObjAttrs = getUDAs!(__traits(getMember, record, fieldName), RightObjAttr);
		static if( isUndefable!FieldType )
		{
			auto field = __traits(getMember, record, fieldName);
			if( field.isUndef )
				continue; // Если поле не изменилось, то права на него не проверяем
			_checkItemRights!(DataStruct, fieldName)(ctx, accessKind);
		} else static if( RightObjAttrs.length > 0 ) {
			_checkItemRights!(DataStruct, fieldName)(ctx, accessKind);
		}
	}
}