module webtank.security.auth.core.utils;

import webtank.db.iface.database: IDatabase;
import webtank.db.iface.factory: IDatabaseFactory;

IDatabase getAuthDB(IDatabaseFactory dbFactory)
{
	import webtank.security.auth.common.exception: AuthException;
	import webtank.db.consts: AUTH_DB;

	import std.exception: enforce;

	enforce!AuthException(dbFactory !is null, `Expected instance of IDatabaseFactory`);
	auto db = dbFactory.getDB(AUTH_DB);
	enforce!AuthException(db !is null, `Expected auth database instance`);
	return db;
}
