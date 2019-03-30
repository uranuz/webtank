module webtank.ivy.datctrl.deserialize;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter;
import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;
import webtank.ivy.datctrl.enum_adapter: EnumAdapter;

void _deserializeFieldInplace(ref IvyData fieldData, IvyData format)
{
	import std.datetime: SysTime, Date;
	import std.exception: enforce;
	if( fieldData.type == IvyDataType.Undef || fieldData.type == IvyDataType.Null ) {
		return; // Dont try to deserialize Null or Undef and return as is
	}

	switch(format["t"].str)
	{
		case "date", "dateTime":
			if( fieldData.type == IvyDataType.String ) {
				fieldData = IvyData(
					format["t"].str == "date"?
					SysTime(Date.fromISOExtString(fieldData.str)):
					SysTime.fromISOExtString(fieldData.str)
				);
			} else {
				enforce(fieldData.type == IvyDataType.DateTime, `Node is node convertible to dateTime`);
			}
			break;
		case "enum": {
			enforce(format.type == IvyDataType.ClassNode, `Expected enum format ClassNode`);
			EnumFormatAdapter fmt = cast(EnumFormatAdapter) format.classNode;
			enforce(fmt !is null, `Expected EnumFormat adapter`);
			fieldData = new EnumAdapter(fmt, fieldData);
			break;
		}
		default:
			break;
	}
}

bool _isContainerRawData(ref IvyData srcNode) {
	return
		srcNode.type == IvyDataType.AssocArray
		&& "t" in srcNode 
		&& srcNode["t"].type == IvyDataType.String;
}

IvyData tryExtractContainer(ref IvyData srcNode)
{	
	if( !_isContainerRawData(srcNode) ) {
		return srcNode;
	}

	switch( srcNode["t"].str )
	{
		case "recordset":
			return IvyData(new RecordSetAdapter(srcNode));
		case "record":
			return IvyData(new RecordAdapter(srcNode));
		case "enum":
			return "d" in srcNode.assocArray? IvyData(new EnumAdapter(srcNode)):	IvyData(new EnumFormatAdapter(srcNode));
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
		srcNode.assocArray[key] = item.tryExtractContainer();
		srcNode.assocArray[key] = item.tryExtractLvlContainers();
	}
	return srcNode;
}