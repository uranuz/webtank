module webtank.net.http.handler.iface;

import webtank.net.http.context: HTTPContext;

///Код результата обработки запроса
enum HTTPHandlingResult {
	mismatched, //Обработчик не соответствует данному запросу
	unhandled,  //Обработчик не смог обработать данный запрос
	handled     //Обработчик успешно обработал запрос
	/*, redirected*/  //Зарезервировано: обработчик перенаправил запрос на другой узел
}

/// Интерфейс обработчика HTTP-запросов приложения
interface IHTTPHandler
{
	/// Метод обработки запроса. Возвращает true, если запрос обработан.
	/// Возвращает false, если запрос не соответствует обработчику
	/// В случае ошибки кидает исключение
	HTTPHandlingResult processRequest(HTTPContext context);
}

/// Интерфейс составного обработчика HTTP-запросов
interface ICompositeHTTPHandler: IHTTPHandler
{
	/// Добавление обработчика запросов
	/// Должен возвращать this в качестве результата
	ICompositeHTTPHandler addHandler(IHTTPHandler handler);
}

///Типы обработчиков, используемых при обработке HTTP-запросов

///Тип обработчика: ошибка при обработке HTTP-запроса
///		error - перехваченное исключение, которое нужно обработать
alias bool delegate(Throwable error, HTTPContext context) ErrorHandler;

///Тип обработчика: начало опроса обработчика HTTP-запроса
alias void delegate(HTTPContext context) PrePollHandler;

///Тип обработчика: начало опроса обработчика HTTP-запроса
///		isMatched - имеет значение true, если запрос соответствует данному обработчику, т.е
///			он по формальным критериям определил, что хочет/может его обработать. Иначе - false
alias void delegate(HTTPContext context, bool isMatched) PostPollHandler;

// ///Тип обработчика: начало обработки HTTP-запроса
// alias void delegate(HTTPContext context) PreProcessHandler;

///Тип обработчика: завершение обработки HTTP-запроса
///		result - результат обработки запроса обработчиком
alias void delegate(HTTPContext context, HTTPHandlingResult result) PostProcessHandler;