module webtank.history.service.service;

import webtank.ivy.backend_service: IvyBackendService;

import webtank.net.http.handler;

import webtank.history.service.record_history: getRecordHistory;
import webtank.history.service.writer: writeDataToHistory, saveActionToHistory;

class HistoryService: IvyBackendService
{
	this(string serviceName)
	{
		super(serviceName);

		pageRouter.joinWebFormAPI!(getRecordHistory)("/history/api/{objectName}/history");

		JSON_RPCRouter.join!(getRecordHistory)(`history.list`);
		JSON_RPCRouter.join!(writeDataToHistory)(`history.writeData`);
		JSON_RPCRouter.join!(saveActionToHistory)(`history.writeAction`);
	}
}