module webtank.net.server.worker;

import std.socket: Socket, SocketShutdown, AddressFamily, SocketType, UnixAddress;
import std.socket: CMSG_SPACE, CMSG_FIRSTHDR, CMSG_LEN, SOL_SOCKET, SCM_RIGHTS, CMSG_DATA, socket_t, cmsghdr, msghdr, iovec, ssize_t, recvmsg;

struct WorkerOpts
{
	string workerSockAddr;
	ushort port = 8082;
	size_t threadCount = 5;
	IHTTPHandler handler;
	Loger loger;
	string kind;
}

void parseWorkerOptsFromCmd(string[] progAgs, ref WorkerOpts opts)
{
	import std.getopt: getopt;
	getopt(progAgs,
		"port", &opts.port,
		"threadCount", &opts.threadCount,
		"workerSockAddr", &opts.workerSockAddr);
}

import webtank.net.server.thread_pool: ThreadPoolServer;
import webtank.net.server.thread_per_connection: ThreadPerConnectionServer;
import webtank.net.http.handler: IHTTPHandler;
import webtank.common.loger: Loger;

void runServer(ref WorkerOpts opts)
{
	import std.exception: enforce;

	enforce(opts.handler !is null, `Server main handler is null`);
	enforce(opts.loger !is null, `Server main loger is null`);
	
	socket_t serverSock;
	if(opts.workerSockAddr.length > 0) {
		serverSock = getSocketHandle(opts.workerSockAddr);
	}
	
	if( opts.kind == `thread_per_connection` ) {
		auto server = (opts.workerSockAddr.length > 0?
			new ThreadPerConnectionServer(serverSock, opts.handler, opts.loger):
			new ThreadPerConnectionServer(opts.port, opts.handler, opts.loger));
		server.start();
	} else {
		auto server = (opts.workerSockAddr.length > 0?
			new ThreadPoolServer(serverSock, opts.handler, opts.loger, opts.threadCount):
			new ThreadPoolServer(opts.port, opts.handler, opts.loger, opts.threadCount));
		server.start();
	}
}

socket_t getSocketHandle(string workerSockAddr)
{
	import std.string: toStringz;
	auto cworkerSockAddr = workerSockAddr.toStringz;
	Socket listener = new Socket(AddressFamily.UNIX, SocketType.STREAM);
	scope(exit) {
		listener.shutdown(SocketShutdown.BOTH);
		listener.close();
		import core.sys.posix.unistd: unlink;
		unlink(cworkerSockAddr);
	}
	
	listener.blocking = true;
	listener.bind(new UnixAddress(workerSockAddr));
	listener.listen(1);
	auto acceptedSock = listener.accept();
	scope(exit) {
		acceptedSock.shutdown(SocketShutdown.BOTH);
		acceptedSock.close();
	}

	return receiveSocketHandle(acceptedSock);
}

socket_t receiveSocketHandle(Socket acceptedSock)
{
	/* Allocate a char array of suitable size to hold the ancillary data.
	However, since this buffer is in reality a 'struct cmsghdr', use a
	union to ensure that it is aligned as required for that structure. */
	static union control_un_t
	{
		cmsghdr cmh;
		char[CMSG_SPACE(int.sizeof)] control;
		/* Space large enough to hold an 'int' */
	}
	
	import std.stdio: writeln;
	import std.conv: text;
	msghdr msgh;
	iovec iov;
	int data;
	int fd;
	ssize_t nr;

	control_un_t control_un;
	cmsghdr* cmhp;

	/* Set 'control_un' to describe ancillary data that we want to receive */

	control_un.cmh.cmsg_len = CMSG_LEN(int.sizeof);
	control_un.cmh.cmsg_level = SOL_SOCKET;
	control_un.cmh.cmsg_type = SCM_RIGHTS;

	/* Set 'msgh' fields to describe 'control_un' */

	msgh.msg_control = control_un.control.ptr;
	msgh.msg_controllen = control_un.control.sizeof;

	/* Set fields of 'msgh' to point to buffer used to receive (real)
		data read by recvmsg() */

	msgh.msg_iov = &iov;
	msgh.msg_iovlen = 1;
	iov.iov_base = &data;
	iov.iov_len = int.sizeof;

	msgh.msg_name = null;               /* We don't need address of peer */
	msgh.msg_namelen = 0;

	/* Receive real plus ancillary data */

	nr = recvmsg(acceptedSock.handle, &msgh, 0);
	if (nr == -1)
		throw new Exception("recvmsg");
	writeln("recvmsg() returned: ", nr);

	if (nr > 0)
		writeln("Received data = ", data.text);

	/* Get the received file descriptor (which is typically a different
		file descriptor number than was used in the sending process) */
	cmhp = CMSG_FIRSTHDR(&msgh);
	if (cmhp is null || cmhp.cmsg_len != CMSG_LEN(int.sizeof))
		throw new Exception("bad cmsg header / message length");
	if (cmhp.cmsg_level != SOL_SOCKET)
		throw new Exception("cmsg_level != SOL_SOCKET");
	if (cmhp.cmsg_type != SCM_RIGHTS)
		throw new Exception("cmsg_type != SCM_RIGHTS");

	fd = *(cast(int*) CMSG_DATA(cmhp));
	writeln("Received fd=", fd);
	return cast(socket_t) fd;
}