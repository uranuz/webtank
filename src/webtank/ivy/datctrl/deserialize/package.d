module webtank.ivy.datctrl.deserialize;

import ivy.types.data: IvyData, IvyDataType;

import webtank.ivy.datctrl._recordset_init; // Used to ensure that module is compiled. Don't delete

IvyData tryExtractLvlContainers(IvyData srcNode)
{
	srcNode = srcNode.tryExtractContainer();
	if( srcNode.type != IvyDataType.AssocArray ) {
		return srcNode;
	}

	foreach( key, item; srcNode.assocArray ) {
		srcNode[key] = item.tryExtractLvlContainers();
	}
	return srcNode;
}

IvyData tryExtractContainer(ref IvyData srcNode)
{	
	import webtank.ivy.datctrl.record_adapter: RecordAdapter;
	import webtank.ivy.datctrl.recordset_adapter: RecordSetAdapter;
	import webtank.ivy.datctrl.enum_format_adapter: EnumFormatAdapter;
	import webtank.ivy.datctrl.enum_adapter: EnumAdapter;
	import webtank.datctrl.consts: SrlEntityType, SrlField;

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
				SrlField.data in srcNode?
				IvyData(new EnumAdapter(srcNode)):
				IvyData(new EnumFormatAdapter(srcNode))
			);
		default: break;
	}
	return srcNode;
}


bool _isContainerRawData(ref IvyData srcNode)
{
	import webtank.datctrl.consts: SrlField;
	return
		srcNode.type == IvyDataType.AssocArray
		&& SrlField.type in srcNode 
		&& srcNode[SrlField.type].type == IvyDataType.String;
}
