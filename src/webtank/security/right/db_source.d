module webtank.security.right.db_source;

import webtank.datctrl.record_format: RecordFormat;
import webtank.datctrl.iface.data_field: PrimaryKey;
import webtank.db.datctrl_joint: getRecordSet;
import webtank.db.database: IDatabase;
import webtank.datctrl.iface.record_set: IBaseRecordSet;
import webtank.datctrl.typed_record_set: TypedRecordSet;

import webtank.security.right.data_source;

class RightDatabaseSource: IRightDataSource
{
private:
	alias GetDBFunc = IDatabase delegate();
	GetDBFunc _getDBFunc;

public:
	this(GetDBFunc getDBFunc)
	{
		import std.exception: enforce;
		enforce(getDBFunc !is null, `Expected database connection function!`);
		_getDBFunc = getDBFunc;
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
			select num, name, parent_num
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
			select num, role_num, object_num, rule_num, access_kind from access_right
			`).getRecordSet(rightRecFormat);
		}
	}
}