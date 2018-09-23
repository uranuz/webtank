module webtank.security.right.composite_rule;

import webtank.security.right.iface.access_rule: IAccessRule;
import webtank.security.access_control: IUserIdentity;
import webtank.security.right.common: RightDataTypes, RightDataVariant;

enum RulesRelation: ubyte
{
	none = 0,
	and = 1,
	or = 2
}

class CompositeAccessRule: IAccessRule
{
private:
	string _name;
	IAccessRule[] _children;
	RulesRelation _relation;

public:
	this(string ruleName = null, RulesRelation rel = RulesRelation.none, IAccessRule[] rules = null)
	{
		_name = ruleName;
		_children = rules;
		_relation = rel;
	}

	public override
	{
		string name() @property {
			return _name;
		}

		bool hasRight(IUserIdentity identity, RightDataVariant data)
		{
			if( _children.length == 0 ) {
				return false; // If there is no rules then access is denied
			}
			if( _relation == RulesRelation.or )
			{
				// "Or" relation among children must be explicitly set, because it is less restrictive
				foreach( child; _children )
				{
					if( child.hasRight(identity, data) ) {
						return true; // One of items returns true then access is allowed
					}
				}
			}
			else
			{
				// By default we have "and" relation among children
				foreach( child; _children )
				{
					if( !child.hasRight(identity, data) ) {
						return false; // One of items returns false then access is denied
					}
				}
				return true; // All checks passed the access is allowed
			}

			return false; // Default is to deny access
		}

		static foreach( alias RightType; RightDataTypes ) {
			bool hasRight(IUserIdentity user, RightType data) {
				return hasRight(user, data);
			}
		}
	}

	override string toString()
	{
		import std.array: join;
		import std.algorithm: map;
		return _children.map!( (it) => it.toString() ).join("\n");
	}

	import std.json: JSONValue;
	override JSONValue toStdJSON()
	{
		import std.array: array;
		import std.algorithm: map;
		import std.conv: text;

		return JSONValue([
			"kind": JSONValue(`CompositeAccessRule`),
			"name": JSONValue(_name),
			"children": JSONValue(_children.map!( (it) => it.toStdJSON() ).array),
			"relation": JSONValue(_relation.text)
		]);
	}
}