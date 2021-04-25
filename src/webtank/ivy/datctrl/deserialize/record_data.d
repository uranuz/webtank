module webtank.ivy.datctrl.deserialize.record_data;

import ivy.types.data: IvyData, IvyDataType;
import webtank.ivy.datctrl.record_format_adapter: RecordFormatAdapter;

IvyData[] _deserializeRecordData(ref IvyData recData, RecordFormatAdapter recFormat)
{
	IvyData[] recordData;
	foreach( i, ref fieldData; recData.array ) {
		recordData ~= _deserializeRecordField(fieldData, recFormat[IvyData(i)]);
	}
	return recordData;
}

IvyData _deserializeRecordField(ref IvyData fieldData, IvyData format)
{
	import ivy.types.data.datetime: IvyDateTime;

	import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;
	import webtank.ivy.datctrl.enum_adapter: EnumAdapter;
	import webtank.ivy.datctrl.field_format_adapter: FieldFormatAdapter;
	import webtank.datctrl.consts: SrlEntityType;

	import std.datetime: SysTime, Date;
	import std.exception: enforce;

	enforce(format.type == IvyDataType.ClassNode, "Expected field format class node");
	if( auto enumFormat = cast(EnumFormatAdapter) format.classNode ) {
		// Enum format is the special case for now
		return IvyData(new EnumAdapter(enumFormat, fieldData));
	}

	if( fieldData.type == IvyDataType.Undef || fieldData.type == IvyDataType.Null ) {
		return fieldData; // Dont try to deserialize Null or Undef and return as is
	}

	FieldFormatAdapter fmt = cast(FieldFormatAdapter) format.classNode;
	enforce(fmt !is null, "Expected field format");

	switch(fmt.typeStr)
	{
		case SrlEntityType.date:
		case SrlEntityType.dateTime:
			enforce(fieldData.type == IvyDataType.String, "Node is node convertible to dateTime");
			fieldData = new IvyDateTime(
				fmt.typeStr == SrlEntityType.date?
				SysTime(Date.fromISOExtString(fieldData.str)):
				SysTime.fromISOExtString(fieldData.str)
			);
			break;
		default:
			break;
	}
	return fieldData;
}


