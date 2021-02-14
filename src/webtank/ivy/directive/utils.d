module webtank.ivy.directive.utils;

import ivy.types.data: IvyData, IvyDataType;

string[][string] extraxtHeaders(IvyData node)
{
	import std.exception: enforce;
	import std.algorithm: canFind, map;
	import std.array: array;

	enforce([
			IvyDataType.AssocArray,
			IvyDataType.Undef,
			IvyDataType.Null
		].canFind(node.type),
		`Expected assoc array of HTTP-headers`);

	string[][string] headers;
	if( node.type != IvyDataType.AssocArray )
		return headers;

	foreach( name, valNode; node.assocArray )
	{
		enforce(valNode.type == IvyDataType.Array, `HTTP header values list expected to be array`);
		headers[name] = valNode.array.map!( (it) {
			enforce(it.type == IvyDataType.String, `HTTP header value expected to be string`);
			return it.str;
		}).array;
	}
	return headers;
}

string getEndpointURI(IvyData[string] allEndpoints, string serviceName, string endpoint = null)
{
	import std.exception: enforce;

	endpoint = endpoint.length > 0? endpoint: "default";

	auto serviceEndpointsPtr = serviceName in allEndpoints; 
	enforce(serviceEndpointsPtr, "No service with name \"" ~ serviceName ~ "\" in config");
	IvyData[string] serviceEndpoints = serviceEndpointsPtr.assocArray;
	auto uriPtr = endpoint in serviceEndpoints;
	enforce(uriPtr, "No endpoint \"" ~ endpoint ~ "\" for service \"" ~ serviceName ~ "\"");
	return uriPtr.str;
}