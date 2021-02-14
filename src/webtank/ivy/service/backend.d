module webtank.ivy.service.backend;

import webtank.net.service.json_rpc: JSON_RPCService;

class IvyBackendService: JSON_RPCService
{
	import webtank.security.auth.iface.controller: IAuthController;
	import webtank.security.auth.client.controller: AuthClientController;
	import webtank.security.right.controller: AccessRightController;
	import webtank.security.right.remote_source: RightRemoteSource;
	import webtank.ivy.access_rule_factory: IvyAccessRuleFactory;
	import webtank.net.service.consts: ServiceRole;

	import ivy.engine: IvyEngine;
	import webtank.ivy.engine: WebtankIvyEngine;

	import std.exception: enforce;

	IvyEngine _ivyEngine;

	// Конструктор сервиса с системой прав по-умлочанию
	this(string serviceName)
	{
		// Создаем сервис с удаленной аутентификацией
		this(serviceName, new AuthClientController(this.config));

		// Устанавливаем получение прав с сервиса аутентификации
		_rights = new AccessRightController(
			new IvyAccessRuleFactory(this._ivyEngine),
			new RightRemoteSource(this.config, ServiceRole.auth, "accessRight.list"));
	}

	// Конструктор сервиса заданным аутентификатором. Конструктор для использования в наследниках
	protected this(string serviceName, IAuthController accessController)
	{
		enforce(accessController, `Access controller expected`);
		super(serviceName);

		// Устанавливаем контроллер аутентификации
		_accessController = accessController;

		// Стартуем шаблонизатор для нужд проверки прав
		_ivyEngine = new WebtankIvyEngine([this.config.fileSystemPaths["siteIvyTemplates"]], this.log);
	}
}