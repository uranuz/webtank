module webtank.security.right.iface.data_source;

import webtank.datctrl.iface.data_field: PrimaryKey;
import webtank.datctrl.typed_record_set: TypedRecordSet;
import webtank.datctrl.record_format: RecordFormat;
import webtank.datctrl.iface.record_set: IBaseRecordSet;

static immutable ruleRecFormat = RecordFormat!(
	PrimaryKey!(size_t), "num",
	string, "name",
	size_t[], "children",
	ubyte, "relation"
)();

static immutable objectRecFormat = RecordFormat!(
	PrimaryKey!(size_t), "num",
	string, "name",
	size_t, "parent_num",
	bool, "is_group"
)();

static immutable roleRecFormat = RecordFormat!(
	PrimaryKey!(size_t), "num",
	string, "name"
)();

static immutable rightRecFormat = RecordFormat!(
	PrimaryKey!(size_t), "num",
	size_t, "role_num",
	size_t, "object_num",
	size_t, "rule_num",
	string, "access_kind",
	bool, "inheritance"
)();

static immutable groupObjectsRecFormat = RecordFormat!(
	PrimaryKey!(size_t), "num",
	size_t, "group_num",
	size_t, "object_num"
)();

interface IRightDataSource
{
	TypedRecordSet!(typeof(ruleRecFormat), IBaseRecordSet) getRules();
	TypedRecordSet!(typeof(objectRecFormat), IBaseRecordSet) getObjects();
	TypedRecordSet!(typeof(roleRecFormat), IBaseRecordSet) getRoles();
	TypedRecordSet!(typeof(rightRecFormat), IBaseRecordSet) getRights();
	TypedRecordSet!(typeof(groupObjectsRecFormat), IBaseRecordSet) getGroupObjects();
}