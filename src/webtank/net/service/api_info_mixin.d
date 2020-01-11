module webtank.net.service.api_info_mixin;

mixin template ServiceAPIInfoMixin()
{
	import webtank.net.http.handler.web_form_api_page_route: joinWebFormAPI;

	import std.json: JSONValue;
	JSONValue _serviceAPI;

	void _initAPIMixin()
	{
		this._rootRouter.joinWebFormAPI!( () => _serviceAPI )(`/api/service/list`);
		// We believe that API doesn't change between service reboots, so cache it forever
		_serviceAPI = this.rootRouter.toStdJSON();
	}
}