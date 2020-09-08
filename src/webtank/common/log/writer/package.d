/++
$(LANG_EN
	This package is about centralization and automatization of event logging
	in application. This information should be used for programme debug
	and diagnostics.
)
$(LANG_RU
	Пакет создан с целью централизации и автоматизации журналирования
	событий, происходящих во время работы. Полученная информация должна
	использоваться для диагностики и отладки системы.
)
+/
module webtank.common.log.writer;

public import webtank.common.log.consts: LogEventType, LogLevel;
public import webtank.common.log.event: LogEvent;
public import webtank.common.log.writer.iface: LogWriter;
public import webtank.common.log.writer.file: FileLogWriter;
public import webtank.common.log.writer.threaded: ThreadedLogWriter;
