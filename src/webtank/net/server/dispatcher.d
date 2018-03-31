module webtank.net.server.dispatcher;

import std.socket: Socket, AddressFamily, SocketType, SocketShutdown, TcpSocket, UnixAddress;
import core.thread: Thread;
import core.time: dur;
import std.process: spawnProcess, wait;

import webtank.net.server.common: ensureBindSocket;

void startDispatchProcess(ushort port, string workerPath, string workerSockAddr = null)
{
	import std.exception: enforce;
	enforce(port > 0, `Port is not set!`);
	enforce(workerPath.length > 0, `workerPath is not set!`);
	import std.path: baseName, buildNormalizedPath, withExtension;
	import std.file: getcwd;
	if( workerSockAddr.length == 0 ) {
		workerSockAddr = buildNormalizedPath(getcwd(), baseName(workerPath) ~ `.sock`);
	}

	Socket listener = new TcpSocket();
	scope(exit)
	{
		listener.shutdown(SocketShutdown.BOTH);
		listener.close();
	}

	listener.ensureBindSocket(port);
	while(true)
	{
		listener.listen(1);
		auto pid = spawnProcess([workerPath, `--workerSockAddr`, workerSockAddr]);
		Thread.sleep( dur!("seconds")(1) );
		Socket workerSock = new Socket(AddressFamily.UNIX, SocketType.STREAM);
		workerSock.blocking = true;
		workerSock.connect(new UnixAddress(workerSockAddr));
		scope(exit)
		{
			workerSock.shutdown(SocketShutdown.BOTH);
			workerSock.close();
			pid.wait();
			Thread.sleep( dur!("seconds")(1) ); // Do not spam things
		}

		workerSock.sendSocketHandle(listener.handle);
	}
}

import std.socket: CMSG_SPACE, CMSG_FIRSTHDR, CMSG_LEN, SOL_SOCKET, SCM_RIGHTS, CMSG_DATA, socket_t, cmsghdr, msghdr, iovec, ssize_t, sendmsg;

void sendSocketHandle(Socket workerSock, socket_t handle)
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

	msghdr msgh;
	iovec iov;
	int data;
	ssize_t ns;
	control_un_t control_un;
	cmsghdr *cmhp;

	/* On Linux, we must transmit at least 1 byte of real data in
		order to send ancillary data */
	msgh.msg_iov = &iov;
	msgh.msg_iovlen = 1;
	iov.iov_base = &data;
	iov.iov_len = int.sizeof;
	data = 666;

	msgh.msg_name = null;
	msgh.msg_namelen = 0;

	msgh.msg_control = control_un.control.ptr;
	msgh.msg_controllen = control_un.control.sizeof;

	writeln("Sending socket handle: ", handle);

	/* Set message header to describe ancillary data that we want to send */
	cmhp = CMSG_FIRSTHDR(&msgh);
	cmhp.cmsg_len = CMSG_LEN(int.sizeof);
	cmhp.cmsg_level = SOL_SOCKET;
	cmhp.cmsg_type = SCM_RIGHTS;
	*(cast(int*) CMSG_DATA(cmhp)) = handle;

	/* Do the actual send */
	ns = sendmsg(workerSock.handle, &msgh, 0);
	if (ns == -1)
		throw new Exception("sendmsg");

	writeln("sendmsg() returned: ", ns);
}