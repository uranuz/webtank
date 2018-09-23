module webtank.security.right.iface.access_rule_factory;

import webtank.security.right.iface.access_rule: IAccessRule;

/// Интерфейс "фабрики" для получения правил доступа
interface IAccessRuleFactory
{
	/// Получить правило доступа по имени или возвращает null, если правило не найдено
	IAccessRule get(string name);
}