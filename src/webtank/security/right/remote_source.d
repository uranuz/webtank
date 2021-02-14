module webtank.security.right.remote_source;

import webtank.datctrl.record_format: RecordFormat;
import webtank.datctrl.iface.data_field: PrimaryKey;
import webtank.datctrl.iface.record_set: IBaseRecordSet, IBaseWriteableRecordSet;
import webtank.datctrl.record_set: WriteableRecordSet;
import webtank.datctrl.typed_record_set: TypedRecordSet;

import webtank.security.right.iface.data_source:
	IRightDataSource,
	ruleRecFormat,
	objectRecFormat,
	roleRecFormat,
	rightRecFormat,
	groupObjectsRecFormat;

import webtank.security.right.access_exception: AccessSystemException, AccessException;

import webtank.net.service.config: IServiceConfig;

class RightRemoteSource: IRightDataSource
{
private:
	IServiceConfig _config;
	string _serviceName;
	string _methodName;
	import std.meta: AliasSeq;
	template RMeta(string field, alias rFmt)
	{
		enum string fieldName = field;
		alias recFormat = rFmt;
	}
	alias RightObjMetas = AliasSeq!(
		RMeta!(`rules`, ruleRecFormat),
		RMeta!(`objects`, objectRecFormat),
		RMeta!(`roles`, roleRecFormat),
		RMeta!(`rights`, rightRecFormat),
		RMeta!(`groupObjects`, groupObjectsRecFormat)
	);

	TypedRecordSet!(typeof(ruleRecFormat), IBaseRecordSet) _rules;
	TypedRecordSet!(typeof(objectRecFormat), IBaseRecordSet) _objects;
	TypedRecordSet!(typeof(roleRecFormat), IBaseRecordSet) _roles;
	TypedRecordSet!(typeof(rightRecFormat), IBaseRecordSet) _rights;
	TypedRecordSet!(typeof(groupObjectsRecFormat), IBaseRecordSet) _groupObjects;
public:
	this(IServiceConfig config, string serviceName, string methodName)
	{
		import std.exception: enforce;
		enforce!AccessSystemException(config, `Expected current service config object`);
		enforce!AccessSystemException(serviceName.length, `Expected rights source endpoint name`);
		enforce!AccessSystemException(methodName.length, `Expected rights source method name`);

		_serviceName = serviceName;
		_methodName = methodName;
		_config = config;
	}

	void _assureLoaded()
	{
		if( _rules is null || _objects is null || _roles is null || _rights is null || _groupObjects is null )
			_loadRights();
	}

	void _loadRights()
	{
		import std.json: JSONValue, JSONType;
		import webtank.net.std_json_rpc_client: remoteCall;
		import std.exception: enforce;

		JSONValue jRightsData = _config.endpoint(_serviceName).remoteCall!JSONValue(_methodName);

		import webtank.common.std_json.from: fromStdJSON;
		foreach( Meta; RightObjMetas )
		{
			auto jRightComponentPtr = Meta.fieldName in jRightsData;
			enforce!AccessSystemException(jRightComponentPtr !is null, `Expected ` ~ Meta.fieldName ~ ` RecordSet in rights data`);
			enforce!AccessSystemException(jRightComponentPtr.type == JSONType.object, `Right component "` ~ Meta.fieldName ~ `" is not an object`);
			auto rightComponent = fromStdJSON!(TypedRecordSet!(typeof(Meta.recFormat), WriteableRecordSet))(*jRightComponentPtr);
			enforce!AccessSystemException(rightComponent !is null, `Right data is null`);
			__traits(getMember, this, `_` ~ Meta.fieldName) = TypedRecordSet!(typeof(Meta.recFormat), IBaseRecordSet)(rightComponent);
		}
	}

	public override {
		TypedRecordSet!(typeof(ruleRecFormat), IBaseRecordSet) getRules() {
			_assureLoaded();
			return _rules;
		}

		TypedRecordSet!(typeof(objectRecFormat), IBaseRecordSet) getObjects() {
			_assureLoaded();
			return _objects;
		}

		TypedRecordSet!(typeof(roleRecFormat), IBaseRecordSet) getRoles() {
			_assureLoaded();
			return _roles;
		}

		TypedRecordSet!(typeof(rightRecFormat), IBaseRecordSet) getRights() {
			_assureLoaded();
			return _rights;
		}

		TypedRecordSet!(typeof(groupObjectsRecFormat), IBaseRecordSet) getGroupObjects() {
			_assureLoaded();
			return _groupObjects;
		}
	}
}
