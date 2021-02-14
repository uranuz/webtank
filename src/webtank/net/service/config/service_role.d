module webtank.net.service.config.service_role;

import std.json: JSONValue;

string[string] getServiceRoles(JSONValue jsonCurrService)
{
	import std.exception: enforce;
	import std.json: JSONType;

	auto serviceRolesPtr = "serviceRoles" in jsonCurrService;
	string[string] res;
	if( serviceRolesPtr is null )
		return res;

	foreach( string serviceRole, JSONValue jServiceName; serviceRolesPtr.object )
	{
		enforce(jServiceName.type == JSONType.string, "Expected string as service name in serviceRoles");
		res[serviceRole] = jServiceName.str;
	}
	return res;
}