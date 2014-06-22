module webtank._version;
//В модуле определяется версия собираемой библиотеки webtank
//По умолчанию всё включено. При определении версии без определенных
//функций мы их выключаем

version(no_webtank_datctrl) enum bool isDatCtrlEnabled = false;
else enum bool isDatCtrlEnabled = true;

version(no_webtank_db) enum bool isDataBaseEnabled = false;
else enum bool isDataBaseEnabled = true;

version(no_webtank_templating) enum bool isTemplatingEnabled = false;
else enum bool isTemplatingEnabled = true;

version(no_webtank_net) enum bool isNetEnabled = false;
else enum bool isNetEnabled = true;

enum string versionString = "0.0";