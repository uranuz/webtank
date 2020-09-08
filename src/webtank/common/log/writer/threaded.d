module webtank.common.log.writer.threaded;

import webtank.common.log.consts: LogLevel;
import webtank.common.log.event: LogEvent;
import webtank.common.log.writer.iface: LogWriter;

/++
$(LANG_EN
	Wrapper log that makes logging work in separate thread
)
$(LANG_RU
	Логер-обертка для работы журналирования в отдельном системном потоке
)
+/
class ThreadedLogWriter: LogWriter
{
	import std.concurrency;
public:
	this(shared(LogWriter) baseLoger) {
		_baseLoger = baseLoger;
	}

	override void writeEvent(LogEvent event)
	{
		if( _logerTid == Tid.init ) {
			_initLogingThread();
		}
		shared(LogEvent) evShared = cast(shared) event;
		send(_logerTid, evShared);
	}

	void _initLogingThread()() {
		synchronized {
			_logerTid = spawn(&_run, thisTid, _baseLoger);
		}
	}

	/++
	$(LANG_EN
		Function stops log and it's thread.
		LogWriter object turns into invalid state after it.
	)
	$(LANG_RU
		Функция останавливает работу логера и завершает связанную с ним
		нить исполнения. Логер переходит в нерабочее состояние после этого
	)
	+/
	override void stop()
	{
		if( _logerTid != Tid.init )
		{
			synchronized {
				if( _logerTid != Tid.init ) {
					send(_logerTid, LogStopMsg());
					_logerTid = Tid.init;
				}
			}
		}
		if( _baseLoger )
		{
			synchronized {
				if( _baseLoger ) {
					(cast(LogWriter)_baseLoger).stop();
				}
			}
		}
	}

	~this() {
		stop();
	}

protected:
	shared(LogWriter) _baseLoger;
	Tid _logerTid;

	struct LogStopMsg {}

	static void _run( Tid ownerTid, shared(LogWriter) baseLoger )
	{
		import std.exception: enforce;
		import std.variant: Variant;
		import std.conv: to;
		
		bool cont = true;
		auto log = cast(LogWriter) baseLoger;
		while(cont)
		{
			receive(
				(shared(LogEvent) ev) {
					enforce(log !is null, `Base log object reference is null!!!`);
					log.writeEvent(ev);
				},
				(LogStopMsg msg) {
					cont = false;
				},
				(OwnerTerminated e) {
					throw e;
				},
				(Variant val) {
					enforce(log !is null, `Base log object reference is null!!!`);
					log.error(`Unexpected message to log thread: ` ~ val.to!string);
				}
			);
		}
	}
}