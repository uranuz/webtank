module webtank.security.auth.core.utils;

import webtank.db.iface.database: IDatabase;
import webtank.db.iface.factory: IDatabaseFactory;

IDatabase getAuthDB(IDatabaseFactory dbFactory)
{
	import webtank.security.auth.common.exception: AuthSystemException;
	import webtank.db.consts: DBRole;

	import std.exception: enforce;

	enforce!AuthSystemException(dbFactory !is null, `Expected instance of IDatabaseFactory`);
	auto db = dbFactory.getDB(DBRole.auth);
	enforce!AuthSystemException(db !is null, `Expected auth database instance`);
	return db;
}
