module webtank.db.datctrl_joint;
///Функционал, объединяющий работу с БД и с набором записей

import std.conv;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.record_set;
import webtank.datctrl.iface.record_set;
import webtank.datctrl.typed_record_set;
import webtank.datctrl.enum_format;
import webtank.db.database;
import webtank.db.database_field;

auto getRecordSet(RecordFormatT)(IDBQueryResult queryResult, RecordFormatT format)
{
	return TypedRecordSet!(RecordFormatT, IBaseRecordSet)(
		new RecordSet(
			makePostgreSQLDataFields(queryResult, format),
			RecordFormatT.getKeyFieldIndex!()));
}

auto getRecord(RecordFormatT)(IDBQueryResult queryResult, RecordFormatT format, bool allowEmpty=false)
{
	import std.exception: enforce;
	auto rs = queryResult.getRecordSet(format);
	if( allowEmpty ) {
		enforce(
			rs !is null && rs.length < 2,
			`Expected one or zero records when using queryRecord (with allowEmpty=true)`);
		return rs.length == 1? rs[0]: typeof(rs[0])();
	}
	// else...
	enforce(
		rs !is null && rs.length == 1,
		`Expected exactly one record when using queryRecord`);
	return rs[0];
}

auto getScalar(T)(IDBQueryResult queryResult)
{
	import std.exception: enforce;
	import webtank.common.conv: conv;
	enforce(
		queryResult !is null && queryResult.fieldCount == 1 && queryResult.recordCount == 1,
		`Expected exactly one record and one field when using queryScalar`);
	enforce(
		!queryResult.isNull(0, 0),
		`Query scalar result expected to be non null`);
	return queryResult.get(0, 0).conv!T();
}

/**
auto queryRecordSet(RecordFormatT)(IDatabase db, RecordFormatT format, string queryStr)
{
	return db.query(queryStr).getRecordSet(format);
}

auto queryRecord(RecordFormatT)(IDatabase db, RecordFormatT format, string queryStr)
{
	import std.exception: enforce;
	auto rs = db.query(queryStr).getRecordSet(format);
	enforce(
		rs !is null && rs.length == 1,
		`Expected exactly one record when using queryScalar`);
	return rs[0];
}

auto queryScalar(T)(IDatabase db, string queryStr)
{
	import std.exception: enforce;
	import webtank.common.conv: conv;
	auto queryRes = db.query(queryStr);
	enforce(
		queryRes !is null && queryRes.fieldCount == 1 && queryRes.recordCount == 1,
		`Expected exactly one record and one field when using queryScalar`);
	enforce(
		!queryRes.isNull(0, 0),
		`Query scalar result expected to be non null`);
	return queryRes.get(0, 0).conv!T();
}
*/