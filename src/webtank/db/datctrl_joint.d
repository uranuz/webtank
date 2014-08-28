module webtank.db.datctrl_joint;
///Функционал, объединяющий работу с БД и с набором записей

import std.conv;

import webtank.db.database, webtank.db.database_field;

import webtank.datctrl.record_format, webtank.datctrl.record_set, webtank.datctrl.data_field, webtank.datctrl.enum_format;

//junction, joint, link, coop



auto getRecordSet(RecordFormatT)(IDBQueryResult queryResult, RecordFormatT format)
{	
	alias RecordSetT = RecordSet!RecordFormatT;
	
	IBaseDataField[] dataFields;
	foreach( fieldName; RecordFormatT.tupleOfNames!() )
	{	alias FieldFormatDecl = RecordFormatT.getFieldFormatDecl!(fieldName);
		alias CurrFieldT = DatabaseField!(FieldFormatDecl);
		alias fieldIndex = RecordFormatT.getFieldIndex!(fieldName);
		
		bool isNullable = format.nullableFlags.get(fieldName, true);
		
		static if( isEnumFormat!(FieldFormatDecl) )
		{	
			alias enumFieldIndex = RecordFormatT.getEnumFormatIndex!(fieldName);
			dataFields ~= new CurrFieldT( queryResult, fieldIndex, fieldName, isNullable,  format.enumFormats[enumFieldIndex] );
		}
		else
			dataFields ~= new CurrFieldT( queryResult, fieldIndex, fieldName, isNullable );
	}
	auto recordSet = new RecordSetT(dataFields);
	return recordSet;
}
