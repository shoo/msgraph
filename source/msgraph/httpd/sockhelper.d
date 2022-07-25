/*******************************************************************************
 * Socket helper functions
 * 
 * $(INTERNAL_MODULE)
 * 
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 */
module msgraph.httpd.sockhelper;

package(msgraph.httpd):

import core.time;
import std.socket;

/*******************************************************************************
 * $(INTERNAL)
 */
bool select(Socket sock, scope bool* readable, scope bool* writable, scope bool* err, Duration timeout) nothrow @trusted
{
	static import core.time;
	SocketSet readfds;
	SocketSet writefds;
	SocketSet errfds;
	SocketSet* preadfds;
	SocketSet* pwritefds;
	SocketSet* perrfds;
	void FD_SET(Socket sock, SocketSet* fds) nothrow { (*fds).add(sock); }
	void FD_CLR(Socket sock, SocketSet* fds) nothrow { (*fds).remove(sock); }
	void FD_ZERO(SocketSet* fds) nothrow
	{
		if (!*fds)
			*fds = new SocketSet;
		(*fds).reset();
	}
	bool FD_ISSET(Socket sock, SocketSet* fds) nothrow { return (*fds).isSet(sock) != 0; }
	if (readable)
	{
		preadfds = &readfds;
		FD_ZERO(&readfds);
		FD_SET(sock, &readfds);
	}
	if (writable)
	{
		pwritefds = &writefds;
		FD_ZERO(&writefds);
		FD_SET(sock, &writefds);
	}
	if (err)
	{
		perrfds = &errfds;
		FD_ZERO(&errfds);
		FD_SET(sock, &errfds);
	}
	try
	{
		if (sock.select(readfds, writefds, errfds, timeout) == -1)
			return false;
	}
	catch (Exception)
	{
		return false;
	}
	
	if (readable)
		*readable = FD_ISSET(sock, &readfds)  != 0;
	if (writable)
		*writable = FD_ISSET(sock, &writefds) != 0;
	if (err)
		*err      = FD_ISSET(sock, &errfds)   != 0;
	return true;
}

/// $(INTERNAL)
void select(
	Socket sock,
	scope void delegate() nothrow @safe @nogc onReadable,
	scope void delegate() nothrow @safe @nogc onWritable,
	scope void delegate() nothrow @safe @nogc onError,
	Duration timeout = 0.msecs) @trusted nothrow
{
	bool readable;
	bool writable;
	bool err;
	if (select(
		sock,
		onReadable ? &readable : null,
		onWritable ? &writable : null,
		onError    ? &err      : null,
		timeout))
	{
		if (readable)
			onReadable();
		if (writable)
			onWritable();
		if (err)
			onError();
	}
}

/// $(INTERNAL)
bool waitReadable(Socket sock, Duration timeout) nothrow @trusted
{
	bool rd, er;
	return select(sock, &rd, null, &er, timeout) && rd && !er;
}

/// $(INTERNAL)
bool waitWritable(Socket sock, Duration timeout) nothrow @trusted
{
	bool wt, er;
	return select(sock, null, &wt, &er, timeout) && wt && !er;
}

/// $(INTERNAL)
void setRecvTimeout(Socket sock, Duration timeout) nothrow @trusted
{
	import std.exception;
	struct TimeVal
	{
		int sec;
		int usec;
	}
	TimeVal[1] dat;
	timeout.split!("seconds", "usecs")(dat[0].sec, dat[0].usec);
	sock.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dat[]).collectException();
}

/// $(INTERNAL)
void setSendTimeout(Socket sock, Duration timeout) nothrow @trusted
{
	import std.exception;
	struct TimeVal
	{
		int sec;
		int usec;
	}
	TimeVal[1] dat;
	timeout.split!("seconds", "usecs")(dat[0].sec, dat[0].usec);
	sock.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, dat[]).collectException();
}
