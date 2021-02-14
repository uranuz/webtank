module webtank.net.service.config.page_routing;

import std.json: JSONValue;

struct RoutingConfigEntry
{
	string pageURI; // Адрес расположения страницы, который обрабатывается сервисом отображения
	string HTTPMethod; // Ограничение на HTTP-метод. Например, можно ограничить запросы на запись методом POST для защиты от случайных GET-запросов
	string ivyModule; // Имя модуля на языке Ivy для отображения результатов
	string ivyMethod; // Имя метода для вызова, который находится на верхнем уровне внутри модуля ivyModule

	bool isValid() @property
	{
		import std.range: empty;
		return !pageURI.empty && !ivyModule.empty && !ivyMethod.empty;
	}
}

RoutingConfigEntry[] getPageRoutesConfig(JSONValue jsonCurrService)
{
	import webtank.common.std_json.from: fromStdJSON;

	JSONValue pageRouting;
	if( "pageRouting" in jsonCurrService ) {
		pageRouting = jsonCurrService["pageRouting"];
	}
	return fromStdJSON!(RoutingConfigEntry[])(pageRouting);
}
