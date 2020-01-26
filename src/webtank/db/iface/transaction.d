module webtank.db.iface.transaction;

interface IDBTransaction
{
	void commit();
	void rollback();
	string exportSnapshot();
}