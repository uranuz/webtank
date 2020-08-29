module webtank.ivy.datctrl.deserialize;

import ivy;
import ivy.compiler.compiler;
import ivy.interpreter.interpreter;
import ivy.types.data;
import ivy.types.data.datetime: IvyDateTime;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter;
import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;
import webtank.ivy.datctrl.enum_adapter: EnumAdapter;
import webtank.ivy.datctrl.field_format_adapter: FieldFormatAdapter;

import webtank.datctrl.consts;

IvyData _deserializeRecordData(ref IvyData fieldData, IvyData format)
{
	import std.datetime: SysTime, Date;
	import std.exception: enforce;

	enforce(format.type == IvyDataType.ClassNode, `Expected field format class node`);
	if( auto fmt = cast(EnumFormatAdapter) format.classNode ) {
		// Enum format is the special case for now
		return IvyData(new EnumAdapter(fmt, fieldData));
	}

	if( fieldData.type == IvyDataType.Undef || fieldData.type == IvyDataType.Null ) {
		return fieldData; // Dont try to deserialize Null or Undef and return as is
	}

	FieldFormatAdapter fmt = cast(FieldFormatAdapter) format.classNode;
	enforce(fmt !is null, `Expected field format`);

	switch(fmt.typeStr)
	{
		case SrlEntityType.date:
		case SrlEntityType.dateTime:
			enforce(fieldData.type == IvyDataType.String, `Node is node convertible to dateTime`);
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

bool _isContainerRawData(ref IvyData srcNode) {
	return
		srcNode.type == IvyDataType.AssocArray
		&& SrlField.type in srcNode 
		&& srcNode[SrlField.type].type == IvyDataType.String;
}

IvyData tryExtractContainer(ref IvyData srcNode)
{	
	if( !_isContainerRawData(srcNode) ) {
		return srcNode;
	}

	switch( srcNode[SrlField.type].str )
	{
		case SrlEntityType.recordSet:
			return IvyData(new RecordSetAdapter(srcNode));
		case SrlEntityType.record:
			return IvyData(new RecordAdapter(srcNode));
		case SrlEntityType.enum_:
			return (
				SrlField.data in srcNode.assocArray?
				IvyData(new EnumAdapter(srcNode)):
				IvyData(new EnumFormatAdapter(srcNode))
			);
		default: break;
	}
	return srcNode;
}

IvyData tryExtractLvlContainers(IvyData srcNode)
{
	srcNode = srcNode.tryExtractContainer();
	if( srcNode.type != IvyDataType.AssocArray ) {
		return srcNode;
	}

	foreach( key, item; srcNode.assocArray ) {
		srcNode.assocArray[key] = item.tryExtractLvlContainers();
	}
	return srcNode;
}