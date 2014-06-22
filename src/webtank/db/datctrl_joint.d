module webtank.db.datctrl_joint;
///Функционал, объединяющий работу с БД и с набором записей

import std.conv;

import webtank.db.database, webtank.db.database_field;

import   webtank.datctrl.record_format, webtank.datctrl.record_set, webtank.datctrl.data_field;

//junction, joint, link, coop



auto getRecordSet(RecordFormatT)(IDBQueryResult queryResult, const(RecordFormatT) format)
{	alias RecordSet!RecordFormatT RecordSetT;
	
	IBaseDataField[] dataFields;
	foreach( i, fieldName; RecordFormatT.tupleOfNames!() )
	{	alias RecordFormatT.getFieldType!(fieldName) fieldType;
		alias DatabaseField!(fieldType) CurrFieldT;
		
		static if( fieldType == FieldType.Enum )
		{	if( fieldName in format.enumFormats )
				dataFields ~= new CurrFieldT( queryResult, i, fieldName, format.enumFormats[fieldName] );
			else
				dataFields ~= new CurrFieldT( queryResult, i, fieldName );
		}
		else
			dataFields ~= new CurrFieldT( queryResult, i, fieldName );
	}
	auto recordSet = new RecordSetT(dataFields);
	recordSet.setKeyField(0);
	return recordSet;
}
