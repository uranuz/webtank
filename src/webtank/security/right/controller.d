module webtank.security.right.controller;

import webtank.security.right.access_rule;
import webtank.security.right.data_source;

class AccessObject
{
private:
	string _name;
	AccessObject[] _children;

public:
	this(string name, AccessObject[] children = null)
	{
		_name = name;
		_children = children;
	}

	string name() @property {
		return _name;
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

import webtank.security.access_control: IUserIdentity;
interface IRightController
{
	bool isAllowed(IUserIdentity user, string accessObject, string accessKind, string[string] data);
}

struct AccessRightKey
{
	size_t roleNum;
	size_t objectNum;
	string accessKind;
}

class AccessRightController
{
	
private:
	CoreAccessRuleStorage _coreStorage;
	IRightDataSource _dataSource;
	IAccessRule[size_t] _allRules;
	AccessObject[size_t] _allObjects;
	string[size_t] _allRoles;
	IAccessRule[AccessRightKey] _rulesByRightKey;

	size_t[string] _objectNumByName;
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

	bool isAllowed(IUserIdentity user, string accessObject, string accessKind, string[string] data)
	{
		_assureLoaded(); // Will load rights lazily
		
		import std.array: split, array;
		import std.algorithm: filter, map;
		import std.string: strip;
		if( accessObject !in _objectNumByName )
			return false;
		size_t objectNum = _objectNumByName[accessObject];

		// Get nonempty role names tha mentioned in list
		string[] userRoles =
			user.data.get("accessRoles", null).split(";")
			.map!( (it) => it.strip() )
			.filter!( (it) => it.length && it in _roleNumByName ).array;
		
		foreach( roleName; userRoles )
		{
			AccessRightKey rightKey = {
				roleNum: _roleNumByName[roleName],
				objectNum: objectNum,
				// Consider null and "" are the same
				accessKind: (accessKind.length? accessKind: null)
			};
			if( auto rule = rightKey in _rulesByRightKey ) {
				if( (*rule).isAllowed(user, data) )
					return true;
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
		if( ruleName.length > 0 && ruleName in _coreStorage ) {
			return _coreStorage[ruleName];
		} else if( auto existing = ruleRec.get!"num" in _allRules ) {
			return *existing;
		}
		IAccessRule newRule = new CompositeAccessRule(
			ruleName,
			cast(RulesRelation) ruleRec.get!"relation"(RulesRelation.none),
			_loadChildRules(ruleRec, rulesRS)
		);
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
		_objectNumByName.clear();
		foreach( objRec; objRS ) {
			_loadObjectWithChildren(objRec, objRS, childKeys);
		}

		import std.exception: enforce;
		foreach( key, obj; _allObjects ) {
			enforce( obj.name !in _objectNumByName, `Duplicated access object name: ` ~ obj.name );
			_objectNumByName[obj.name] = key;
		}
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
		AccessObject newObj = new AccessObject(objRec.get!"name", childObjs);
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
				(rightRec.getStr!"access_kind"().length? rightRec.getStr!"access_kind"(): null)
			)] = rule;
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
