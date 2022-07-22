/*******************************************************************************
 * Socket helper functions
 * 
 * $(INTERNAL_MODULE)
 */
module msgraph.httpd.sockhelper;

package(msgraph.httpd):


import std.socket;

/*******************************************************************************
 * $(INTERNAL)
 */
bool select(Socket sock, scope bool* readable, scope bool* writable, scope bool* err, in uint msecs) nothrow @trusted
{
	static import core.time;
	auto tim = core.time.msecs(msecs);
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
		if (sock.select(readfds, writefds, errfds, tim) == -1)
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
	in uint msecs = 0) @trusted nothrow
{
	bool readable;
	bool writable;
	bool err;
	if (select(
		sock,
		onReadable ? &readable : null,
		onWritable ? &writable : null,
		onError    ? &err      : null,
		msecs))
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
bool waitReadable(Socket sock, uint msecs) nothrow @trusted
{
	bool rd, er;
	return select(sock, &rd, null, &er, msecs) && rd && !er;
}

/// $(INTERNAL)
bool waitWritable(Socket sock, uint msecs) nothrow @trusted
{
	bool wt, er;
	return select(sock, null, &wt, &er, msecs) && wt && !er;
}

/// $(INTERNAL)
void setRecvTimeout(Socket sock, uint msecs) nothrow @trusted
{
	import std.exception;
	struct TimeVal
	{
		int sec;
		int usec;
	}
	TimeVal[1] dat = [TimeVal(msecs / 1000, (msecs % 1000) * 1000)];
	sock.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dat[]).collectException();
}

/// $(INTERNAL)
void setSendTimeout(Socket sock, uint msecs) nothrow @trusted
{
	import std.exception;
	struct TimeVal
	{
		int sec;
		int usec;
	}
	TimeVal[1] dat = [TimeVal(msecs / 1000, (msecs % 1000) * 1000)];
	sock.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, dat[]).collectException();
}
