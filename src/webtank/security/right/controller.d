module webtank.security.right.controller;

import webtank.security.right.iface.access_rule: IAccessRule;
import webtank.security.right.iface.data_source: IRightDataSource;

class AccessObject
{
private:
	import webtank.common.optional: Optional;
	string _name;
	AccessObject[] _children;
	Optional!size_t _parentNum;

public:
	this(string name, AccessObject[] children = null, Optional!size_t parent = Optional!size_t())
	{
		_name = name;
		_children = children;
		_parentNum = parent;
	}

	string name() @property {
		return _name;
	}

	Optional!size_t parentNum() @property {
		return _parentNum;
	}

	import std.json: JSONValue;
	JSONValue toStdJSON()
	{
		import std.array: array;
		import std.algorithm: map;
		import std.conv: text;

		return JSONValue([
			"name": JSONValue(_name),
			"children": JSONValue(_children.map!( (it) => it.toStdJSON() ).array)
		]);
	}
}

struct AccessRightKey
{
	size_t roleNum;
	size_t objectNum;
	string accessKind;
	bool inheritance;
}

import webtank.security.right.iface.controller: IRightController;

class AccessRightController: IRightController
{
	
private:
	import webtank.security.right.core_storage: CoreAccessRuleStorage;
	import webtank.security.access_control: IUserIdentity;
	import webtank.security.right.composite_rule: CompositeAccessRule, RulesRelation;
	import std.typecons: Tuple;

	alias RuleWithFlag = Tuple!(IAccessRule, "rule", bool, "inheritance");

	CoreAccessRuleStorage _coreStorage;
	IRightDataSource _dataSource;
	IAccessRule[size_t] _allRules;
	AccessObject[size_t] _allObjects;
	string[size_t] _allRoles;
	RuleWithFlag[AccessRightKey] _rulesByRightKey;

	size_t[string] _objectNumByFullName;
	size_t[string] _roleNumByName;

public:
	this(CoreAccessRuleStorage coreStorage, IRightDataSource dataSource)
	{
		import std.exception: enforce;
		enforce(coreStorage !is null, `Expected core rules storage!`);
		enforce(dataSource !is null, `Expected rights data source!`);
		_coreStorage = coreStorage;
		_dataSource = dataSource;
	}

	this(IRightDataSource dataSource)
	{
		this(
			new CoreAccessRuleStorage(),
			dataSource
		);
	}

	void reloadRightsData()
	{
		loadDBAccessRules();
		loadDBAccessObjects();
		loadDBAccessRoles();
		loadDBAccessRights();
	}

	private void _assureLoaded()
	{
		// If all of these are empty then consider that nothing was load yet
		if( _allRules is null && _allObjects is null && _allRoles is null )
			reloadRightsData();
	}

	override public bool hasRight(IUserIdentity user, string accessObject, string accessKind, string[string] data)
	{
		if( !user.isAuthenticated() ) {
			return false; // Not permission if user is not authenticated
		}

		_assureLoaded(); // Will load rights lazily
		
		import std.array: split, array, join;
		import std.algorithm: filter, map, splitter;
		import std.range: empty, dropBack, popBack, save;
		import std.string: strip;
		if( accessObject !in _objectNumByFullName )
			return false;
		size_t objectNum = _objectNumByFullName[accessObject];

		// Get nonempty role names tha mentioned in the list
		string[] userRoles =
			user.data.get("accessRoles", null).split(";")
			.map!( (it) => it.strip() )
			.filter!( (it) => it.length && it in _roleNumByName ).array;

		size_t[] parentObjects;
		for(
			string[] shortParentObjects = accessObject.splitter(".").filter!( (it) => it.length > 0 ).array.dropBack(1);
			!shortParentObjects.empty;
			shortParentObjects.popBack()
		) {
			string parentObj = shortParentObjects.save.join(".");
			if( auto it = parentObj in _objectNumByFullName ) {
				parentObjects ~= *it;
			} else {
				break; // If there is no innest parent then there is no logic to search for outer parent
			}
		}

		foreach( roleName; userRoles )
		{
			AccessRightKey rightKey = {
				roleNum: _roleNumByName[roleName],
				objectNum: objectNum,
				// Consider null and "" are the same
				accessKind: (accessKind.length? accessKind: null)
			};
			if( auto item = rightKey in _rulesByRightKey ) {
				if( item.rule.hasRight(user, data) )
					return true;
				continue; // Do not search in parent object if have specialized right
			}
			parents_loop:
			foreach( parentObjNum; parentObjects )
			{
				rightKey.objectNum = parentObjNum;
				if( auto item = rightKey in _rulesByRightKey ) {
					if( !item.inheritance ) {
						continue parents_loop;
					} else if( item.rule.hasRight(user, data) ) {
						return true;
					} else {
						break parents_loop;
					}
				}
			}
		}
		return false;
	}

	/++ Load all access rules from database into _allRules +/
	void loadDBAccessRules()
	{
		auto ruleRS = _dataSource.getRules();
		_allRules.clear();
		foreach( ruleRec; ruleRS ) {
			_loadRuleWithChildren(ruleRec, ruleRS);
		}
	}

	IAccessRule _loadRuleWithChildren(REC, RS)(ref REC ruleRec, ref RS rulesRS)
	{
		if( auto already = ruleRec.get!"num" in _allRules ) {
			return *already;
		}
		
		string ruleName = ruleRec.get!"name";
		IAccessRule newRule;
		if( auto coreRule = ruleName in _coreStorage ) {
			newRule = *coreRule;
		} else {
			newRule = new CompositeAccessRule(
				ruleName,
				cast(RulesRelation) ruleRec.get!"relation"(RulesRelation.none),
				_loadChildRules(ruleRec, rulesRS)
			);
		}
		_allRules[ruleRec.get!"num"] = newRule;
		return newRule;
	}

	IAccessRule[] _loadChildRules(REC, RS)(ref REC ruleRec, ref RS rulesRS)
	{
		IAccessRule[] childRules;
		foreach( num; ruleRec.get!"children"(null) ) {
			auto childRec = rulesRS.getRecordByKey(num);
			childRules ~= _loadRuleWithChildren(childRec, rulesRS);
		}
		return childRules;
	}

	void loadDBAccessObjects()
	{
		auto objRS = _dataSource.getObjects();

		// For each item get list of children keys
		size_t[][size_t] childKeys;
		foreach( objRec; objRS )
		{
			if( objRec.isNull("parent_num") ) {
				continue;
			}

			if( auto currChilds = objRec.get!"parent_num" in childKeys ) {
				*currChilds ~= objRec.get!"num";
			} else {
				childKeys[objRec.get!"parent_num"] = [objRec.get!"num"];
			}
		}

		_allObjects.clear();
		_objectNumByFullName.clear();
		foreach( objRec; objRS ) {
			_loadObjectWithChildren(objRec, objRS, childKeys);
		}

		import std.exception: enforce;
		foreach( key, obj; _allObjects )
		{
			string fullName = getFullObjectName(obj);
			enforce(fullName !in _objectNumByFullName, `Duplicated access object name: ` ~ obj.name);
			_objectNumByFullName[fullName] = key;
		}
	}

	string getFullObjectName(AccessObject obj)
	{
		import std.exception: enforce;
		import std.conv: text;
		string result;
		while(obj !is null)
		{
			result = obj.name ~ (result.length? ".": null) ~ result;
			if( obj.parentNum.isNull ) {
				break;
			}
			auto parentPtr = obj.parentNum.value in _allObjects;
			enforce(parentPtr !is null, `Could not find parent access object by num: ` ~ obj.parentNum.text);
			obj = *parentPtr;
		}
		return result;
	}

	AccessObject _loadObjectWithChildren(REC, RS)(ref REC objRec, ref RS objRS, size_t[][size_t] childKeys)
	{
		if( auto already = objRec.get!"num" in _allObjects ) {
			return *already;
		}
		
		AccessObject[] childObjs;
		foreach( size_t childKey; childKeys.get(objRec.get!"num", null) )
		{
			if( auto existing = childKey in _allObjects ) {
				childObjs ~= *existing;
			} else {
				auto childRec = objRS.getRecordByKey(childKey);
				childObjs ~= _loadObjectWithChildren(childRec, objRS, childKeys);
			}
		}
		import webtank.common.optional: Optional;
		AccessObject newObj = new AccessObject(
			objRec.get!"name", childObjs,
			(objRec.isNull("parent_num")?
				Optional!size_t():
				Optional!size_t(objRec.get!"parent_num"))
		);
		_allObjects[objRec.get!"num"] = newObj;
		return newObj;
	}

	void loadDBAccessRoles()
	{
		auto roleRS = _dataSource.getRoles();

		foreach( roleRec; roleRS )
		{
			_allRoles[roleRec.get!"num"] = roleRec.getStr!"name";
			import std.exception: enforce;
			enforce( roleRec.getStr!"name" !in _roleNumByName, `Duplicated role with name: ` ~ roleRec.getStr!"name" );
			_roleNumByName[roleRec.getStr!"name"] = roleRec.get!"num";
		}
	}

	void loadDBAccessRights()
	{
		auto rightRS = _dataSource.getRights();

		foreach( rightRec; rightRS )
		{
			// Currently skip rights without role, or object, or rule specification
			if( rightRec.isNull("role_num") || rightRec.isNull("object_num") || rightRec.isNull("rule_num") )
				continue;

			if( rightRec.get!"role_num" !in _allRoles )
				continue;
			if( rightRec.get!"object_num" !in _allObjects )
				continue;
			IAccessRule rule = _allRules.get(rightRec.get!"rule_num", null);
			if( rule is null )
				continue;

			_rulesByRightKey[AccessRightKey(
				rightRec.get!"role_num",
				rightRec.get!"object_num",
				// Consider null and "" are the same
				(rightRec.getStr!"access_kind".length? rightRec.getStr!"access_kind": null)
			)] = RuleWithFlag(
				rule, (rightRec.isNull("inheritance")? false: rightRec.get!"inheritance")
			);
		}
	}

	CoreAccessRuleStorage ruleStorage() @property {
		assert(_coreStorage, `Core access rule storage is not initialized!!!`);
		return _coreStorage;
	}

	IRightDataSource rightSource() @property {
		assert(_coreStorage, `Right source is not initialized!!!`);
		return _dataSource;
	}
}
