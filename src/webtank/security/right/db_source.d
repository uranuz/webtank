module webtank.security.right.db_source;

import webtank.datctrl.record_format: RecordFormat;
import webtank.datctrl.iface.data_field: PrimaryKey;
import webtank.db.datctrl: getRecordSet;
import webtank.db.iface.factory: IDatabaseFactory;
import webtank.datctrl.iface.record_set: IBaseRecordSet;
import webtank.datctrl.typed_record_set: TypedRecordSet;

import webtank.security.right.iface.data_source:
	IRightDataSource,
	ruleRecFormat,
	objectRecFormat,
	roleRecFormat,
	rightRecFormat,
	groupObjectsRecFormat;

import webtank.security.right.access_exception: AccessSystemException;

class RightDatabaseSource: IRightDataSource
{
	private IDatabaseFactory _dbFactory;

public:
	this(IDatabaseFactory dbFactory)
	{
		import std.exception: enforce;
		enforce!AccessSystemException(dbFactory !is null, `Expected database factory for access rights database`);
		_dbFactory = dbFactory;
	}

	public override {
		TypedRecordSet!(typeof(ruleRecFormat), IBaseRecordSet) getRules()
		{
			return _getDBFunc().query(`
			select num, name, to_jsonb(children) "children", relation
			from access_rule
			`).getRecordSet(ruleRecFormat);
		}

		TypedRecordSet!(typeof(objectRecFormat), IBaseRecordSet) getObjects()
		{
			return _getDBFunc().query(`
			select num, name, parent_num, is_group
			from access_object
			`).getRecordSet(objectRecFormat);
		}

		TypedRecordSet!(typeof(roleRecFormat), IBaseRecordSet) getRoles()
		{
			return _getDBFunc().query(`
			select num, name from access_role
			`).getRecordSet(roleRecFormat);
		}

		TypedRecordSet!(typeof(rightRecFormat), IBaseRecordSet) getRights()
		{
			return _getDBFunc().query(`
			select num, role_num, object_num, rule_num, access_kind, inheritance
			from access_right
			`).getRecordSet(rightRecFormat);
		}

		TypedRecordSet!(typeof(groupObjectsRecFormat), IBaseRecordSet) getGroupObjects()
		{
			return _getDBFunc().query(`
			select num, group_num, object_num
			from access_group_object
			`).getRecordSet(groupObjectsRecFormat);
		}
	}

	auto _getDBFunc() {
		return _dbFactory.getDB(`authDB`);
	}
}
