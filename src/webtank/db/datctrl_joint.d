module webtank.db.datctrl_joint;
///Функционал, объединяющий работу с БД и с набором записей

import std.conv;

import webtank.datctrl.iface.data_field;
import webtank.datctrl.record_format;
import webtank.datctrl.record_set;
import webtank.datctrl.typed_record_set;
import webtank.datctrl.enum_format;
import webtank.db.database;
import webtank.db.database_field;

auto getRecordSet(RecordFormatT)(IDBQueryResult queryResult, RecordFormatT format)
{
	return TypedRecordSet!(RecordFormatT, RecordSet)(
		new RecordSet(
			makePostgreSQLDataFields(queryResult, format),
			RecordFormatT.getKeyFieldIndex!()
		)
	);
}
