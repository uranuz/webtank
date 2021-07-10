module webtank.ivy.access_rule;

import ivy.types.data: IvyData, IvyDataType;
import ivy.engine: IvyEngine;
import ivy.types.data.conv.std_to_ivy_json: toIvyJSON;

import webtank.security.right.iface.access_rule: IAccessRule;
import webtank.security.right.common: RightDataTypes, RightDataVariant;
import webtank.security.auth.iface.user_identity: IUserIdentity;
import webtank.ivy.user: IvyUserIdentity;
import webtank.datctrl.iface.record: IBaseRecord;

import std.json: JSONValue;
import std.exception: enforce;
import std.variant: visit;

class IvyAccessRule: IAccessRule
{
	this(IvyEngine ivyEngine, string ruleName)
	{
		import std.exception: enforce;
		enforce(ivyEngine, `Expected ivy engine`);
		enforce(ruleName.length, `Expected rule name`);
		_ivyEngine = ivyEngine;
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
		//enforce(splitted.length >= 2, `Expected at least module and directive names in ivy rule name`);
		if( splitted.length < 2 ) {
			return false;
		}
		string moduleName;
		string methodName;

		if( splitted.length == 2 )
		{
			moduleName = splitted[0];
			methodName = splitted[1];
		}
		else
		{
			enforce(splitted[0] == `ivy`, `Expected "ivy" prefix as first argument`);
			moduleName = splitted[1];
			methodName = splitted[2];
		}

		auto asyncRes = _ivyEngine.runMethod(
			moduleName,
			methodName, [
				`identity`: IvyData(new IvyUserIdentity(identity)),
				`data`: IvyData(data)
			]);
		enforce(asyncRes.isResolved, "Expected resolved async result of right check method!");

		IvyData res;
		asyncRes.then((it) => res = it);

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
	IvyEngine _ivyEngine;
	string _name;
}
