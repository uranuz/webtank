module webtank.db.datctrl;
///Функционал, объединяющий работу с БД и с набором записей

import std.conv;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.record_set;
import webtank.datctrl.iface.record_set;
import webtank.datctrl.typed_record_set;
import webtank.datctrl.enum_format;
import webtank.db;
import webtank.db.field;

import webtank.db.iface.query_result: IDBQueryResult;

auto getRecordSet(RecordFormatT)(IDBQueryResult queryResult, RecordFormatT format)
{
	static if( RecordFormatT.hasWriteableSpec ) {
		alias RecordSetT = WriteableRecordSet;
		alias RecordSetIface = IBaseWriteableRecordSet;
	} else {
		alias RecordSetT = RecordSet;
		alias RecordSetIface = IBaseRecordSet;
	}
	
	return TypedRecordSet!(RecordFormatT, RecordSetIface)(
		new RecordSetT(
			makeDataFields(queryResult, format),
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
	import webtank.common.optional: isNullableType, isUnsafelyNullable;
	bool isSet = (
		queryResult !is null
		&& queryResult.fieldCount == 1
		&& queryResult.recordCount == 1
		&& !queryResult.isNull(0, 0)
	);
	static if( isNullableType!T && !isUnsafelyNullable!T ) {
		if( !isSet )
			return null;
	} else {
		enforce(isSet, `Incorrect scalar query result`);
	}
	return queryResult.get(0, 0).conv!T();
}
