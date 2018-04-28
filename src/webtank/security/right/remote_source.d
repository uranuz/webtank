module webtank.security.right.remote_source;

import webtank.datctrl.record_format: RecordFormat;
import webtank.datctrl.iface.data_field: PrimaryKey;
import webtank.datctrl.iface.record_set: IBaseRecordSet, IBaseWriteableRecordSet;
import webtank.datctrl.typed_record_set: TypedRecordSet;

import webtank.security.right.data_source;
import webtank.net.service.iface: IWebService;

class RightRemoteSource: IRightDataSource
{
private:
	IWebService _thisService;
	string _serviceName;
	string _methodName;
	TypedRecordSet!(typeof(ruleRecFormat), IBaseRecordSet) _ruleRS;
	TypedRecordSet!(typeof(objectRecFormat), IBaseRecordSet) _objectRS;
	TypedRecordSet!(typeof(roleRecFormat), IBaseRecordSet) _roleRS;
	TypedRecordSet!(typeof(rightRecFormat), IBaseRecordSet) _rightRS;
public:
	this(IWebService thisService, string serviceName, string methodName)
	{
		import std.exception: enforce;
		enforce(thisService, `Expected current service link for getting configuration`);
		enforce(serviceName.length, `Expected rights source endpoint name`);
		enforce(methodName.length, `Expected rights source method name`);

		_serviceName = serviceName;
		_methodName = methodName;
		_thisService = thisService;
	}

	void _assureLoaded()
	{
		if( _ruleRS is null || _objectRS is null || _roleRS is null || _rightRS is null )
			_loadRights;
	}

	void _loadRights()
	{
		import std.json: JSONValue;
		import webtank.net.std_json_rpc_client: remoteCall;
		import std.exception: enforce;

		JSONValue jRightsData = _thisService.endpoint(_serviceName).remoteCall!JSONValue(_methodName);
		enforce(`rules` in jRightsData, `Expected rules RecordSet in rights data!!!`);
		enforce(`objects` in jRightsData, `Expected objects RecordSet in rights data!!!`);
		enforce(`roles` in jRightsData, `Expected roles RecordSet in rights data!!!`);
		enforce(`rights` in jRightsData, `Expected rights RecordSet in rights data!!!`);
		import webtank.common.std_json.from: fromStdJSON;
		auto tmpRules = fromStdJSON!(TypedRecordSet!(typeof(ruleRecFormat), IBaseWriteableRecordSet))(jRightsData[`rules`]);
		_ruleRS = TypedRecordSet!(typeof(ruleRecFormat), IBaseRecordSet)(tmpRules);
		auto tmpObjects = fromStdJSON!(TypedRecordSet!(typeof(objectRecFormat), IBaseWriteableRecordSet))(jRightsData[`objects`]);
		_objectRS = TypedRecordSet!(typeof(objectRecFormat), IBaseRecordSet)(tmpObjects);
		auto tmpRoles = fromStdJSON!(TypedRecordSet!(typeof(objectRecFormat), IBaseWriteableRecordSet))(jRightsData[`roles`]);
		_roleRS = TypedRecordSet!(typeof(roleRecFormat), IBaseRecordSet)(tmpRoles);
		auto tmpRights = fromStdJSON!(TypedRecordSet!(typeof(rightRecFormat), IBaseWriteableRecordSet))(jRightsData[`rights`]);
		_rightRS = TypedRecordSet!(typeof(rightRecFormat), IBaseRecordSet)(tmpRights);
	}

	public override {
		TypedRecordSet!(typeof(ruleRecFormat), IBaseRecordSet) getRules() {
			return _ruleRS;
		}

		TypedRecordSet!(typeof(objectRecFormat), IBaseRecordSet) getObjects() {
			return _objectRS;
		}

		TypedRecordSet!(typeof(roleRecFormat), IBaseRecordSet) getRoles() {
			return _roleRS;
		}

		TypedRecordSet!(typeof(rightRecFormat), IBaseRecordSet) getRights() {
			return _rightRS;
		}
	}
}