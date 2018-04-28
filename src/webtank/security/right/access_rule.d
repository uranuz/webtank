module webtank.security.right.access_rule;

class CoreAccessRuleStorage
{
private:
	IAccessRule[string] _rules;

public:
	import std.exception: enforce;
	void join(IAccessRule rule)
	{
		enforce(rule.name.length, `Access rule should have name!`);
		enforce(rule.name !in _rules, `Rule name must be unique!`);
		_rules[rule.name] = rule;
	}

	IAccessRule opIndex(string name)
	{
		enforce(name in _rules, `No access rule name found with name: ` ~ name);
		return _rules[name];
	}

	IAccessRule* opBinaryRight(string op: "in")(string name) {
		return name in _rules;
	}
}

import webtank.security.access_control: IUserIdentity;
import std.json: JSONValue;

interface IAccessRule
{
	string name() @property;
	bool isAllowed(IUserIdentity identity, string[string] data = null);
	string toString();
	JSONValue toStdJSON();
}

enum RulesRelation: ubyte
{
	none = 0,
	and = 1,
	or = 2
}

alias AccessRuleDelType = bool delegate(IUserIdentity identity, string[string] data);

class PlainAccessRule: IAccessRule
{
private:
	string _name;
	AccessRuleDelType _del;

public:
	this(string name, AccessRuleDelType deleg)
	{
		_name = name;
		_del = deleg;
	}

	public override
	{
		string name() @property {
			return _name;
		}

		bool isAllowed(IUserIdentity identity, string[string] data = null)
		{
			if( _del !is null ) {
				return false;
			}
			return _del(identity, data);
		}
	}

	override string toString()
	{
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

		bool isAllowed(IUserIdentity identity, string[string] data)
		{
			if( _children.length == 0 ) {
				return false; // If there is no rules then access is denied
			}
			if( _relation == RulesRelation.or )
			{
				// "Or" relation among children must be explicitly set, because it is less restrictive
				foreach( child; _children )
				{
					if( child.isAllowed(identity, data) ) {
						return true; // One of items returns true then access is allowed
					}
				}
			}
			else
			{
				// By default we have "and" relation among children
				foreach( child; _children )
				{
					if( !child.isAllowed(identity, data) ) {
						return false; // One of items returns false then access is denied
					}
				}
				return true; // All checks passed the access is allowed
			}

			return false; // Default is to deny access
		}
	}

	override string toString()
	{
		import std.array: join;
		import std.algorithm: map;
		return _children.map!( (it) => it.toString() ).join("\n");
	}

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