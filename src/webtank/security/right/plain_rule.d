module webtank.security.right.plain_rule;

import webtank.security.right.iface.access_rule: IAccessRule;
import webtank.security.auth.iface.user_identity: IUserIdentity;
import webtank.security.right.common: RightDataTypes, RightDataVariant;
import webtank.security.right.access_exception: AccessSystemException;

import webtank.datctrl.iface.record: IBaseRecord;

version(Have_ivy) import ivy.types.data: IvyData, IvyDataType;

import ivy.types.data.conv.std_to_ivy_json: toIvyJSON;

import std.meta: staticMap;
import std.variant: Algebraic, visit;
import std.exception: enforce;
import std.json: JSONValue, JSONType;

alias AddAccessRuleDelType(RightType) = bool delegate(IUserIdentity identity, RightType data);
alias AccessRuleDelTypes = staticMap!(AddAccessRuleDelType, RightDataTypes);
alias AccessRuleDelVariant = Algebraic!AccessRuleDelTypes;


class PlainAccessRule: IAccessRule
{
private:
	string _name;
	AccessRuleDelVariant _del;

public:
	this(string name, AccessRuleDelVariant deleg)
	{
		_name = name;
		_del = deleg;
	}

	static foreach( DelType; AccessRuleDelTypes )
	{
		this(string name, DelType deleg)
		{
			_name = name;
			_del = deleg;
		}
	}

	public override {
		string name() @property {
			return _name;
		}

		bool hasRight(IUserIdentity identity, RightDataVariant data)
		{
			auto result = data.visit!(
				(JSONValue dat) => hasRight(identity, dat),
				(IBaseRecord dat) => hasRight(identity, dat),
				(IvyData dat) => hasRight(identity, dat),
				() {
					return _del.visit!(
						(AddAccessRuleDelType!(JSONValue) del) {
							return del(identity, JSONValue());
						},
						(AddAccessRuleDelType!(IBaseRecord) del) {
							return del(identity, IBaseRecord.init);
						},
						(AddAccessRuleDelType!(IvyData) del) {
							return del(identity, IvyData());
						},
						() {
							enforce!AccessSystemException(false, `Unexpected handler type!`);
							return false;
						}
					)();
				}
			)();

			return result;
		}

		bool hasRight(IUserIdentity identity, JSONValue data)
		{
			return _del.visit!(
				(AddAccessRuleDelType!(JSONValue) del) {
					return del(identity, data);
				},
				(AddAccessRuleDelType!(IBaseRecord) del) {
					enforce!AccessSystemException(false, `Conversion is not implemented yet!`);
					return false;
				},
				(AddAccessRuleDelType!(IvyData) del) {
					return del(identity, data.toIvyJSON());
				},
				() {
					enforce!AccessSystemException(false, `Unexpected handler type!`);
					return false;
				}
			)();
		}

		bool hasRight(IUserIdentity identity, IBaseRecord data)
		{
			return _del.visit!(
				(AddAccessRuleDelType!(JSONValue) del) {
					return del(identity, data.toStdJSON());
				},
				(AddAccessRuleDelType!(IBaseRecord) del) {
					return del(identity, data);
				},
				(AddAccessRuleDelType!(IvyData) del) {
					enforce!AccessSystemException(false, `Conversion is not implemented yet!`);
					return false;
				},
				() {
					enforce!AccessSystemException(false, `Unexpected handler type!`);
					return false;
				}
			)();
		}

		version(Have_ivy)
		bool hasRight(IUserIdentity identity, IvyData data)
		{
			return _del.visit!(
				(AddAccessRuleDelType!(JSONValue) del) {
					return del(identity, data.toStdJSON());
				},
				(AddAccessRuleDelType!(IBaseRecord) del) {
					enforce!AccessSystemException(false, `Conversion is not implemented yet!`);
					return false;
				},
				(AddAccessRuleDelType!(IvyData) del) {
					return del(identity, data);
				},
				() {
					enforce!AccessSystemException(false, `Unexpected handler type!`);
					return false;
				}
			)();
		}
	}

	override string toString() {
		return `PlainAccessRule: ` ~ _name;
	}

	override JSONValue toStdJSON()
	{
		return JSONValue([
			"kind": "PlainAccessRule",
			"name": name
		]);
	}
}