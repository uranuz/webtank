module webtank.history.service.record_history;

import webtank.common.std_json.to: toStdJSON;
import webtank.net.http.context: HTTPContext;
import webtank.common.optional: Optional;
import webtank.datctrl.navigation: Navigation;
import webtank.net.service.json_rpc: JSON_RPCServiceContext;
import webtank.db.consts: DBRole;

import webtank.history.common;

import webtank.datctrl.record_format;
import webtank.datctrl.iface.data_field;
import webtank.db;
import webtank.db.datctrl;

import std.datetime: DateTime;
static immutable historyRecFormat = RecordFormat!(
	PrimaryKey!(size_t, "num"),
	string, "data",
	size_t, "userNum",
	DateTime, "time_stamp"
)();

import std.json: JSONValue, parseJSON, JSONType;
JSONValue getRecordHistory(JSON_RPCServiceContext ctx, RecordHistoryFilter filter, Navigation nav)
{
	import webtank.security.right.access_exception: AccessException;
	import webtank.datctrl.record_set;

	import webtank.history.service.utils: assertHasHistoryObjects;

	import std.conv: to, text;
	import std.string: join;
	import std.algorithm: canFind;
	import std.exception: enforce;

	enforce!AccessException(
		ctx.rights.hasRight(filter.objectName ~ `.history`, `read`),
		`Недостаточно прав для просмотра истории изменений!`);

	auto db = ctx.service.getDB(DBRole.history);

	assertHasHistoryObjects(db, [filter.objectName]);

	nav.offset.getOrSet(0); nav.pageSize.getOrSet(10); // Задаем параметры по умолчанию
	auto history_rs = db.queryParams(`
	select
		num,
		data,
		user_num,
		time_stamp
	from "_hc__` ~ filter.objectName ~ `"
	where rec_num = $1
	order by time_stamp, num
	offset $2 limit $3
	`, filter.num, nav.offset, nav.pageSize).getRecordSet(historyRecFormat);


	JSONValue[] items;
	JSONValue prevData;
	foreach( rec; history_rs )
	{
		JSONValue item = [
			"rec": JSONValue(rec.get!"num"()),
			"data": JSONValue(),
			"userNum": (rec.isNull("userNum")? JSONValue(): JSONValue(rec.get!"userNum"())),
			"time_stamp": (rec.isNull("time_stamp")? JSONValue(): JSONValue(rec.get!"time_stamp"().toISOExtString())),
		];
		JSONValue data = rec.getStr!`data`().parseJSON();
		JSONValue changes = (JSONValue[string]).init;
		if( data.type == JSONType.object )
		{
			if( prevData.type == JSONType.object )
			{
				foreach( string num, JSONValue val; data )
				{
					if( auto prevVal = num in prevData )
					{
						if( *prevVal != val )
							changes[num] = val;
					} else if( val.type != JSONType.null_ ) {
						changes[num] = null;
					}
				}
				foreach( string num, JSONValue val; prevData )
				{
					if( num !in data && val.type != JSONType.null_ )
						changes[num] = null;
				}
			}
			item["data"] = data;
			item["changes"] = changes;
		}
		items ~= item;
		prevData = data;
	}
	
	import std.range: retro;
	import std.array: array;
	return JSONValue([
		`history`: JSONValue(items.retro.array),
		`objectName`: JSONValue(filter.objectName)
	]);
}