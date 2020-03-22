module webtank.history.client;

import webtank.net.std_json_rpc_client;
import webtank.net.http.context: HTTPContext;
import webtank.common.optional: Optional, Undefable;
import webtank.net.service.consts: ServiceRole;

import webtank.history.common;

import std.uuid;
import std.json: JSONValue, JSONType;
import webtank.common.std_json.to: toStdJSON;

/// Добавить запись о совершаемом действии в историю
UUID sendActionToHistory(HTTPContext ctx, string description, Undefable!size_t userNum = Undefable!size_t())
{
	import std.datetime: Clock, UTC, DateTime;
	import std.conv: to;

	UUID namespaceUUID = sha1UUID(`somenamespace`);
	UUID newActionUUID = sha1UUID(randomUUID().toString(), namespaceUUID);
	UUID parentUUID;
	if( userNum.isUndef ) {
		userNum = ctx.user.data.get(`userNum`, `0`).to!size_t;
	}

	HistoryActionData data = {
		uuid: newActionUUID.toString(),
		parentUUID: parentUUID.toString(),
		description: description,
		userNum: userNum,
		time_stamp: cast(DateTime) Clock.currTime(UTC())
	};

	ctx.endpoint(ServiceRole.history).remoteCall!(JSONValue)(
		`history.writeAction`, ["data": data.toStdJSON()]);
	return newActionUUID;
}

/// Сохранить изменения в историю (для одной записи)
void sendChangesToHistory(HTTPContext ctx, HistoryRecordData data) {
	sendChangesToHistory(ctx, [data]);
}

/// Сохранить изменения в историю (несколько записей)
void sendChangesToHistory(HTTPContext ctx, HistoryRecordData[] data)
{
	import std.exception: enforce;
	import std.conv: to;
	import std.range: chunks;

	size_t userNum = ctx.user.data.get(`userNum`, `0`).to!size_t;
	foreach( ref item; data )
	{
		enforce!Exception(!item.recordNum.isNull, `Record num must be specified!`);
		enforce!Exception(item.tableName.length, `Table name be specified!`);

		// Номер пользователя берется из контекста, если не задан явно
		if( item.userNum.isUndef ) {
			item.userNum = userNum;
		}
	}

	foreach( piece; data.chunks(400) )
		ctx.endpoint(ServiceRole.history).remoteCall!(JSONValue)(
			`history.writeData`, ["data": piece.toStdJSON()]);
}

// Записать действие в историю и сохранить изменения
void sendToHistory(HTTPContext ctx, string description, HistoryRecordData data) {
	sendToHistory(ctx, description, [data]);
}

// Записать действие в историю и сохранить изменения
void sendToHistory(HTTPContext ctx, string description, HistoryRecordData[] data)
{
	auto actionUUID = sendActionToHistory(ctx, description).toString();
	foreach( ref item; data ) {
		item.actionUUID = actionUUID;
	}
	sendChangesToHistory(ctx, data);
}