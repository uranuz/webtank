module webtank.common.log.consts;

/++
$(LANG_EN
	Log event type
)
$(LANG_RU
	Тип журналируемого события
)
+/
enum LogEventType
{
	/++
	$(LANG_EN This is fatal error event. Proper work of application or recovery is impossible)
	$(LANG_RU Фатальная ошибка. Дальнейшая работа или восстановление после неё невозможно)
	+/
	fatal,

	/++
	$(LANG_EN This is critical error event. There serious problems in system. Recovery is hardly possible
		and sometimes can lead to undefined consequences.
	)
	$(LANG_RU Критическая ошибка. Дальнейшая работа существенно затруднена, либо ведёт к неизвестным последствиям)
	+/
	crit,

	/++
	$(LANG_EN This is regular error during execution. Usually it can be handled and programme can continue
		to work in normal mode
	)
	$(LANG_RU Обычная ошибка во время работы. Такая ошибка, как правило, может быть обработана
		и программа может продолжить работу в штатном режиме
	)
	+/
	error,

	/++
	$(LANG_EN This is warning about unexpected or "suspicious" conditions)
	$(LANG_RU Предупреждение о возможных неприятных последствиях или "подозрительных" условиях работы)
	+/
	warn,

	/++
	$(LANG_EN This is informational message about some events in system)
	$(LANG_RU Информационное сообщение о событиях в системе)
	+/
	info,

	/++
	$(LANG_EN This is message with key information for debugging)
	$(LANG_RU Сообщение с основной информацией для отладки)
	+/
	dbg,

	/++
	$(LANG_EN This is super verbose message for traсing and debugging purposes including
		lots of information about programme state, variables, etc.
	)
	$(LANG_RU Сообщение с расширенной информацией для отладки, включающее расширенные
		сведения о состоянии программы, переменных и т.д.
	)
	+/
	trace
}

/++
$(LANG_EN
	Level of verbosity of log
)
$(LANG_RU
	"Уровень логирования" (общая степень детализации журнала)
)
+/
enum LogLevel
{	none,
	fatal,
	crit,
	error,
	warn,
	info,
	dbg,
	trace,
	full
}