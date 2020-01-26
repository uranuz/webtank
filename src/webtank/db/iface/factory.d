module webtank.db.iface.factory;

import webtank.db: IDatabase;

interface IDatabaseFactory
{
	IDatabase getDB(string dbID);
}