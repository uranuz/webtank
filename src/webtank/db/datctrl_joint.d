module webtank.db.datctrl_joint;
///Функционал, объединяющий работу с БД и с набором записей

import std.conv;

import webtank.db.database, webtank.db.database_field;

import webtank.datctrl.record_format, webtank.datctrl.record_set, webtank.datctrl.data_field, webtank.datctrl.enum_format;

//junction, joint, link, coop



auto getRecordSet(RecordFormatT)(IDBQueryResult queryResult, const(RecordFormatT) format)
{	
	alias RecordSetT = RecordSet!RecordFormatT;
	
	IBaseDataField[] dataFields;
	foreach( i, fieldName; RecordFormatT.tupleOfNames!() )
	{	alias FieldFormatDecl = RecordFormatT.getFieldFormatDecl!(fieldName);
		alias CurrFieldT = DatabaseField!(FieldFormatDecl);
		
		bool isNullable = format.nullableFlags.get(fieldName, true);
		
		static if( isEnumFormat!(FieldFormatDecl) )
		{	if( fieldName in format.enumFormats )
				dataFields ~= new CurrFieldT( queryResult, i, fieldName, isNullable,  format.enumFormats[fieldName] );
			else
				dataFields ~= new CurrFieldT( queryResult, i, fieldName, isNullable );
		}
		else
			dataFields ~= new CurrFieldT( queryResult, i, fieldName, isNullable );
	}
	auto recordSet = new RecordSetT(dataFields);
	return recordSet;
}
