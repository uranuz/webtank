module webtank.history.service.writer;

import webtank.history.common;

import webtank.db.transaction: makeTransaction;
import webtank.db: queryParams;
import webtank.db.utils: PGEscapeStr, PGEscapeIdent;
import webtank.common.optional: Optional;
import webtank.security.right.access_exception: AccessException;
import webtank.net.service.json_rpc_service: JSON_RPCServiceContext;
import webtank.db.consts: DBRole;
import webtank.db.iface.database: IDatabase;
import webtank.datctrl.record_format: RecordFormat, PrimaryKey;
import webtank.db.datctrl: getRecordSet, getScalar;

import std.uuid;
import std.json;
import std.exception: enforce;

void writeDataToHistory(JSON_RPCServiceContext ctx, HistoryRecordData[] data)
{
	import webtank.history.service.utils: assertHasHistoryObjects;
	import std.algorithm: map, uniq;
	import std.array: array;

	enforce!AccessException(ctx.user.isAuthenticated, `Недостаточно прав для записи в историю!!!`);

	auto db = ctx.service.getDB(DBRole.history);

	assertHasHistoryObjects(db, data.map!( (it) => it.tableName ).uniq.array);

	HistoryRecordData[][string] byTableData;

	ctx.service.log.info(`Подготовка записи изменений в историю`);

	// Распределяем записи по таблицам
	foreach( item; data )
	{
		enforce(item.tableName.length, `"tableName" field expected!!!`);
		enforce(item.recordNum.isSet, `"recordNum" field expected!!!`);
		enforce(item.userNum.isSet, `"userNum" field expected!!!`);

		if( auto itemsPtr = item.tableName in byTableData ) {
			(*itemsPtr) ~= item;
		} else {
			byTableData[item.tableName] = [item];
		}
	}

	ctx.service.log.info(`Запуск записи изменений в историю`);

	foreach( tableName, tableData; byTableData ) {
		writeDataForTable(db, tableData, tableName);
	}
	ctx.service.log.info(`Завершение записи изменений в историю`);
}

void writeDataForTable(IDatabase db, HistoryRecordData[] data, string tableName)
{
	auto trans = db.makeTransaction();
	scope(failure) trans.rollback();
	scope(success) trans.commit();

	import std.algorithm: map, filter;
	import std.array: array;
	import std.datetime: DateTime;

	import webtank.common.optional: Optional, Undefable;

	alias goodItemsFilter = (it) => it.recordNum.isSet;

	size_t[] recNums = data.filter!(goodItemsFilter).map!( (it) => it.recordNum.value ).array;

	if( recNums.length == 0 ) {
		return; // Нечего писать
	}

	auto changeRS = db.queryParams(`
	with rec_nums(num) as(
		select unnest($1::bigint[])
	)
	select
		tab.num change_num,
		rec_nums.num rec_num
	from rec_nums
	inner join "_hc__` ~ PGEscapeIdent(tableName) ~ `" tab
		on
			tab.rec_num = rec_nums.num
			and
			tab.is_last = true
	for update
	`, recNums).getRecordSet(RecordFormat!(
		PrimaryKey!(size_t, "changeNum"),
		size_t, `recNum`
	)());
	// Словарь: по номеру записи получаем её последнее изменение в истории
	size_t[size_t] historyNums;
	foreach( changeRec; changeRS )
	{
		if(	changeRec.isNull(`changeNum`) || changeRec.isNull(`recNum`) )
			continue;

		historyNums[changeRec.get!`recNum`()] = changeRec.get!`changeNum`();
	}

	JSONValue[] datas;
	Undefable!(DateTime)[] timeStamps;
	Undefable!(size_t)[] userNums;
	ubyte[] recKinds;
	Optional!(size_t)[] prevNums;
	string[] actionUuids;

	foreach( ref HistoryRecordData item; data )
	{
		if( !goodItemsFilter(item) ) {
			continue;
		}
		datas ~= item.data;
		timeStamps ~= item.time_stamp;
		userNums ~= item.userNum;
		recKinds ~= cast(ubyte) item.recordKind;
		auto prevNumPtr = item.recordNum.value in historyNums;
		prevNums ~= (prevNumPtr is null? Optional!size_t(): Optional!size_t(*prevNumPtr));
		actionUuids ~= item.actionUUID;
	}
	// Вставка новых данных в историю
	db.queryParams(`
	insert into "_hc__` ~ PGEscapeIdent(tableName) ~ `"
	(
		rec_num,
		data,
		time_stamp,
		user_num,
		rec_kind,
		prev_num,
		action_num,
		is_last
	)
	select
		dat.rec_num,
		dat.data,
		(case
			when dat.time_stamp is null
				then current_timestamp at time zone 'UTC'
			else
				dat.time_stamp
		end) time_stamp
		dat.user_num,
		dat.rec_kind,
		dat.prev_num,
		(
			select num
			from _history_action ha
			where ha.uuid_num = dat.action_uuid
		) action_num,
		true is_last
	from(
		select
			unnest($1::integer[]) rec_num,
			unnest($2::jsonb[]) data,
			unnest($3::timestamp without time zone[]) time_stamp,
			unnest($4::bigint[]) user_num,
			unnest($5::smallint[]) rec_kind,
			unnest($6::bigint[]) prev_num,
			unnest($7::uuid[]) action_uuid
	) as dat
	`, recNums, datas, timeStamps, userNums, recKinds, prevNums, actionUuids);

	// Убираем флаг is_last у записей которые 
	db.queryParams(`
	with nums(num) as(
		select unnest($1::bigint[])
	)
	update "_hc__` ~ PGEscapeIdent(tableName) ~ `"
	set is_last = null
	where num in (select num from nums)
	`, historyNums.byValue.array);
}


size_t saveActionToHistory(JSON_RPCServiceContext ctx, HistoryActionData data)
{
	enforce!AccessException(ctx.user.isAuthenticated, `Недостаточно прав для записи в историю!!!`);

	ctx.service.log.info(`Начало записи действия в историю`);
	scope(success) ctx.service.log.info(`Окончание записи действия в историю`);

	return ctx.service.getDB(DBRole.history).queryParams(`
insert into "_history_action"
(description, time_stamp, user_num, uuid_num, parent_num)
values(
	$1::text,
	$2::timestamp without time zone,
	$3::bigint,
	$4::uuid,
	(
		select num from _history_action ha
		where ha.uuid_num = $5::uuid
		limit 1
	)::bigint
)
returning num`,
		data.description,
		data.time_stamp.toISOExtString(),
		data.userNum,
		data.uuid,
		data.parentUUID
	).getScalar!size_t();
}