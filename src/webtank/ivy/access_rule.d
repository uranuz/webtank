module webtank.ivy.access_rule;

import webtank.security.right.iface.access_rule: IAccessRule;
import webtank.security.right.common: RightDataTypes, RightDataVariant;
import webtank.security.access_control: IUserIdentity;
import webtank.ivy.service_mixin: IIvyServiceMixin;
import ivy.interpreter.data_node: IvyData, IvyDataType;
import webtank.ivy.user: IvyUserIdentity;
import webtank.datctrl.iface.record: IBaseRecord;
import ivy.json: toIvyJSON;

import std.json: JSONValue;
import std.exception: enforce;
import std.variant: visit;

class IvyAccessRule: IAccessRule
{
	this(IIvyServiceMixin ivyService, string ruleName)
	{
		_ivyService = ivyService;
		_name = ruleName;
	}
	
	string name() @property {
		return _name;
	}

public override {
	bool hasRight(IUserIdentity identity, RightDataVariant data = RightDataVariant())
	{
		return data.visit!(
			(JSONValue dat) => hasRight(identity, dat),
			(IBaseRecord dat) => hasRight(identity, dat),
			(IvyData dat) => hasRight(identity, dat),
			() => hasRight(identity, IvyData())
		)();
	}

	bool hasRight(IUserIdentity identity, JSONValue data) {
		return hasRight(identity, data.toIvyJSON());
	}

	bool hasRight(IUserIdentity identity, IBaseRecord data)
	{
		enforce(false, `Not implemented yet!`);
		return false;
	}

	bool hasRight(IUserIdentity identity, IvyData data)
	{
		import std.algorithm: startsWith, splitter, canFind;
		import std.array: split;
		string[] splitted = name.split(":");
		enforce(splitted.length >= 2, `Expected at least module and directive names in ivy rule name`);
		string moduleName;
		string dirName;

		if( splitted.length == 2 )
		{
			moduleName = splitted[0];
			dirName = splitted[1];
		}
		else
		{
			enforce(splitted[0] == `ivy`, `Expected "ivy" prefix as first argument`);
			moduleName = splitted[1];
			dirName = splitted[2];
		}

		IvyData res = _ivyService.runIvyMethodSync(moduleName, dirName, IvyData([
			`identity`: IvyData(new IvyUserIdentity(identity)),
			`data`: IvyData(data)
		]));
		enforce([
			IvyDataType.Undef,
			IvyDataType.Null,
			IvyDataType.Boolean
		], `Expected Undef, Null or Boolean as rights check result`);
		return res.type == IvyDataType.Boolean? res.boolean: false;
	}

	string toString() {
		return `IvyAccessRule: ` ~ _name;
	}

	JSONValue toStdJSON()
	{
		return JSONValue([
			"kind": "IvyAccessRule",
			"name": _name
		]);
	}
}
private:
	IIvyServiceMixin _ivyService;
	string _name;
}
