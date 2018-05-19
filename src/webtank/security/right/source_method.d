module webtank.security.right.source_method;

import webtank.security.right.iface.data_source: IRightDataSource;

import std.json: JSONValue;
JSONValue getAccessRightList(IRightDataSource rightSource)
{
	import std.exception: enforce;
	enforce(rightSource, `Right source must not be null!!!`);
	return JSONValue([
		`rules`: rightSource.getRules().toStdJSON(),
		`objects`: rightSource.getObjects().toStdJSON(),
		`roles`: rightSource.getRoles().toStdJSON(),
		`rights`: rightSource.getRights().toStdJSON(),
		`groupObjects`: rightSource.getGroupObjects().toStdJSON()
	]);
}