module webtank.security.right.source_method;

import webtank.security.right.iface.data_source: IRightDataSource;

import std.typecons: tuple;
auto getAccessRightList(IRightDataSource rightSource)
{
	import std.exception: enforce;
	enforce(rightSource, `Right source must not be null!!!`);
	return tuple!("rules", "objects", "roles", "rights", "groupObjects")(
		rightSource.getRules(),
		rightSource.getObjects(),
		rightSource.getRoles(),
		rightSource.getRights(),
		rightSource.getGroupObjects()
	);
}