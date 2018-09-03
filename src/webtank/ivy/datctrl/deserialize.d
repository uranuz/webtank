module webtank.ivy.datctrl.deserialize;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter;

void _deserializeFieldInplace(ref IvyData fieldData, IvyData format)
{
	import std.datetime: SysTime, Date;
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
				assert(fieldData.type == IvyDataType.DateTime, `Node is node convertible to dateTime`);
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

auto tryExtractRecordSet(ref IvyData srcNode)
{
	if( !_isContainerRawData(srcNode) && srcNode["t"].str != "recordset" ) {
		return null;
	}
	return new RecordSetAdapter(srcNode);
}

auto tryExtractRecord(ref IvyData srcNode)
{
	if( !_isContainerRawData(srcNode) && srcNode["t"].str != "record" ) {
		return null;
	}
	return new RecordAdapter(srcNode);
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
		default: break;
	}
	return srcNode;
}

IvyData tryExtractLvlContainers(IvyData srcNode)
{
	srcNode = srcNode.tryExtractContainer();
	if( srcNode.type != IvyDataType.AssocArray )
		return srcNode;

	foreach( key, item; srcNode.assocArray ) {
		srcNode.assocArray[key] = srcNode.assocArray[key].tryExtractContainer();
	}
	return srcNode;
}