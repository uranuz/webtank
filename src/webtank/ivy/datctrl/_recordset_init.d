module webtank.ivy.datctrl._recordset_init;

/// Initialization of global class split into separate module because of circular dependencies
shared static this()
{
	import webtank.ivy.datctrl.recordset_adapter: RecordSetAdapter;
	import webtank.ivy.datctrl.recordset_adapter_slice: RecordSetAdapterSlice;

	import ivy.types.data.decl_class: DeclClass, makeClass;
	
	RecordSetAdapter._declClass = makeClass!RecordSetAdapter("RecordSetAdapter");
	RecordSetAdapterSlice._declClass = makeClass!RecordSetAdapterSlice("RecordSetAdapterSlice");
}