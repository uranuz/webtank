module webtank.history.service.utils;

import webtank.db;
import webtank.db.datctrl;

string[] nonExistentHistoryObjects(IDatabase db, string[] objectNames)
{
	return db.queryParams(`
		with inp(tab) as(
			select '_hc__' || unnest($1::text[])
		)
		select coalesce(array_agg(inp.tab), ARRAY[]::text[])
		from inp
		left join information_schema.tables tbs
			on tbs.table_name = inp.tab
		where
			tbs.table_name is null
	`, objectNames).getScalar!(string[]);
}


// Проверяем существование таблицы для хранения истории
void assertHasHistoryObjects(IDatabase db, string[] objectNames)
{
	import std.exception: enforce;
	import std.string: join;
	enforce(
		nonExistentHistoryObjects(db, objectNames).length == 0,
		`Отсутствует история изменений по объектам: ` ~ objectNames.join(`, `));
}