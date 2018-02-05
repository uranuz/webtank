module webtank.ivy.datctrl.deserialize;

import ivy, ivy.compiler.compiler, ivy.interpreter.interpreter, ivy.common, ivy.interpreter.data_node;
import webtank.ivy.datctrl.record_adapter;
import webtank.ivy.datctrl.recordset_adapter;

void _deserializeFieldInplace(ref TDataNode fieldData, TDataNode format)
{
	import std.datetime: SysTime, Date;
	if( fieldData.type == DataNodeType.Undef || fieldData.type == DataNodeType.Null ) {
		return; // Dont try to deserialize Null or Undef and return as is
	}

	switch(format["t"].str)
	{
		case "date", "dateTime":
			if( fieldData.type == DataNodeType.String ) {
				fieldData = TDataNode(
					format["t"].str == "date"?
					SysTime(Date.fromISOExtString(fieldData.str)):
					SysTime.fromISOExtString(fieldData.str)
				);
			} else {
				assert(fieldData.type == DataNodeType.DateTime, `Node is node convertible to dateTime`);
			}
		default:
			break;
	}
}

bool _isContainerRawData(ref TDataNode srcNode) {
	return
		srcNode.type == DataNodeType.AssocArray
		&& "t" in srcNode 
		&& srcNode["t"].type == DataNodeType.String;
}

auto tryExtractRecordSet(ref TDataNode srcNode)
{
	if( !_isContainerRawData(srcNode) && srcNode["t"].str != "recordset" ) {
		return null;
	}
	return new RecordSetAdapter(srcNode);
}

auto tryExtractRecord(ref TDataNode srcNode)
{
	if( !_isContainerRawData(srcNode) && srcNode["t"].str != "record" ) {
		return null;
	}
	return new RecordAdapter(srcNode);
}

TDataNode tryExtractContainer(ref TDataNode srcNode)
{
	if( !_isContainerRawData(srcNode) ) {
		return srcNode;
	}

	switch( srcNode["t"].str )
	{
		case "recordset":
			return TDataNode(new RecordSetAdapter(srcNode));
		case "record":
			return TDataNode(new RecordAdapter(srcNode));
		default: break;
	}
	return srcNode;
}

TDataNode tryExtractLvlContainers(TDataNode srcNode)
{
	srcNode = srcNode.tryExtractContainer();
	if( srcNode.type != DataNodeType.AssocArray )
		return srcNode;

	foreach( key, item; srcNode.assocArray ) {
		srcNode.assocArray[key] = srcNode.assocArray[key].tryExtractContainer();
	}
	return srcNode;
}