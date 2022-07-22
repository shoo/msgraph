/*******************************************************************************
 * Simple HTTP daemon
 * 
 * $(INTERNAL_MODULE)
 */
module msgraph.httpd.daemon;

package(msgraph):

import msgraph.httpd.sockhelper;
import msgraph.httpd.parse;

/*******************************************************************************
 * $(INTERNAL) HTTP daemon
 */
struct Httpd
{
private:
	import std.socket;
	import std.exception;
	Socket _listener;
	Socket _connection;
	
public:
	/***************************************************************************
	 * 
	 */
	this(string bindaddr, ushort port = 0) @safe
	{
		listen(bindaddr, port);
	}
	
	/***************************************************************************
	 * 
	 */
	void listen(string bindaddr = "localhost", ushort port = 0) @trusted
	{
		_listener = new TcpSocket;
		_listener.blocking = false;
		_listener.bind(new InternetAddress(bindaddr, port));
		_listener.listen(1);
	}
	
	/***************************************************************************
	 * 
	 */
	ushort listeningPort() @trusted const
	{
		if (auto addr = cast(InternetAddress)((cast()_listener).localAddress))
			return addr.port;
		return 0;
	}
	
	/***************************************************************************
	 * 
	 */
	void closeListener() @trusted
	{
		if (_listener)
		{
			_listener.close();
			_listener = null;
		}
	}
	
	/***************************************************************************
	 * 
	 */
	void closeClient() @trusted
	{
		if (_connection)
		{
			_connection.close();
			_connection = null;
		}
	}
	
	/***************************************************************************
	 * 
	 */
	bool receive(out Request req, uint msecs = uint.max) @safe
	{
		import std.array;
		import std.datetime.stopwatch;
		import std.string;
		import std.algorithm;
		import std.conv;
		bool ret = true;
		uint elapse = 0;
		ubyte[1024] recvBuffer;
		auto app = appender!(ubyte[]);
		auto sw = StopWatch(AutoStart.yes);
		
		bool checkElapse()
		{
			elapse = cast(uint)sw.peek.total!"msecs";
			return elapse < msecs;
		}
		bool readData()
		{
			while (1)
			{
				if (!checkElapse())
					return false;
				setRecvTimeout(_connection, msecs - elapse);
				auto recvlen = _connection.receive(recvBuffer);
				if (recvlen == -1)
					continue;
				if (recvlen == 0)
					break;
				app ~= recvBuffer[0..recvlen];
				break;
			}
			return true;
		}
		
		// 接続の待ち受け
		if (!waitReadable(_listener, msecs - elapse))
			return ret = false;
		_connection = _listener.accept();
		
		scope (exit) if (!ret)
			closeClient();
		
		size_t headerIndex;
		size_t bodyIndex;
		// ヘッダ位置確認
		while (_connection.isAlive)
		{
			// 受信
			if (!readData())
				return ret = false;
			// デリミタ検出
			auto idx = app.data[0..$].countUntil([0x0d, 0x0a]);
			if (idx == -1)
				continue;
			headerIndex = idx + 2;
			break;
		}
		
		assert(headerIndex >= 2);
		
		// メソッド・パス・プロトコルバージョン検出
		if (!req.parseRequestLine(cast(char[])app.data[0..headerIndex-2]))
			return ret = false;
		assert(req.method.length > 0);
		assert(req.path.length > 0);
		assert(req.protocolVersion.length > 0);
		
		// ヘッダ受信
		while (1)
		{
			// デリミタ検出
			auto idx = app.data[headerIndex..$].countUntil([0x0d, 0x0a, 0x0d, 0x0a]);
			if (idx != -1)
			{
				bodyIndex = headerIndex + idx + 4;
				break;
			}
			if (!_connection.isAlive)
				return ret = false;
			
			// 受信
			if (!readData())
				return ret = false;
		}
		assert(bodyIndex - headerIndex >= 4);
		
		// ヘッダ解析
		if (!req.parseHeaders(cast(const(char)[])app.data[headerIndex..bodyIndex-4]))
			return ret = false;
		if (req.method.toLower == "get")
			return ret = true;
		
		size_t contentLen;
		if (auto lenStr = "content-length" in req.header)
			contentLen = to!uint(*lenStr);
		if (contentLen == 0)
			return ret = false;
		
		// ボディ受信
		while (app.data.length - bodyIndex < contentLen && _connection.isAlive)
		{
			if (!readData())
				return ret = false;
		}
		if (!req.parseBody(cast(const(char)[])app.data[bodyIndex .. $]))
			return ret = false;
		return ret = true;
	}
	
	/***************************************************************************
	 * 
	 */
	bool send(Response res, uint msecs = 1000) @safe
	{
		import std.datetime;
		import std.datetime.stopwatch;
		import std.algorithm;
		import std.conv;
		import std.string;
		bool ret = true;
		uint elapse = 0;
		auto sw = StopWatch(AutoStart.yes);
		bool checkElapse()
		{
			elapse = cast(uint)sw.peek.total!"msecs";
			return elapse > msecs;
		}
		bool sendData(string dat)
		{
			auto sendbuf = dat.representation[];
			size_t sent = 0;
			while (1)
			{
				setSendTimeout(_connection, msecs - elapse);
				auto sendlen = _connection.send(sendbuf);
				if (sendlen == -1 || sendbuf.length < sendlen)
					return false;
				sendbuf = sendbuf[sendlen..$];
				if (sendbuf.length == 0)
					break;
			}
			return true;
		}
		scope (exit)
			closeClient();
		
		// ステータスライン送信
		if (!sendData(res.status ~ "\x0d\x0a"))
			return false;
		static immutable monLut = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
		static immutable weekLut = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
		SysTime now = Clock.currTime.toUTC();
		auto date = format("%s, %02d %s %04d %02d:%02d:%02d GMT",
			weekLut[now.dayOfWeek], now.day, monLut[now.month-1], now.year,
			now.hour, now.minute, now.second);
		// ヘッダ送信
		if (!sendData("Date: " ~ date ~ "\x0d\x0a"))
			return false;
		if (!sendData("Server: httpd" ~ "\x0d\x0a"))
			return false;
		if (!sendData("Content-Length: " ~ res.content.length.to!string ~ "\x0d\x0a"))
			return false;
		foreach (pair; res.header.byKeyValue)
		{
			if (!sendData(pair.key ~ ": " ~ pair.value ~ "\x0d\x0a"))
				return false;
		}
		if (!sendData("Connection: close\x0d\x0a"))
			return false;
		if (!sendData("\x0d\x0a"))
			return false;
		
		// ボディ送信
		if (!sendData(res.content))
			return false;
		
		return true;
	}
	
	/***************************************************************************
	 * 
	 */
	void close() @safe
	{
		closeListener();
		closeClient();
	}
	
	~this() @safe
	{
		close();
	}
}

///
@safe unittest
{
	import std.socket;
	import std.parallelism;
	import std.string;
	import std.range;
	import std.algorithm;
	Httpd httpd;
	httpd.listen();
	ushort port = httpd.listeningPort;
	auto t = task({
		// curlでGET確認
		import std.net.curl: get, HTTP;
		auto client = HTTP();
		client.setUserAgent("hoge");
		auto res = get(format!"http://localhost:%d"(port), client);
		assert(res == "SUCCESS");
		assert(client.responseHeaders["content-type"] == "text/plain");
		assert(client.statusLine.code == 200);
		assert(client.statusLine.reason == "OK");
	});
	t.executeInNewThread();
	Request req;
	auto reqresult = httpd.receive(req, 1000);
	assert(reqresult);
	assert(req.header["host"] == format!"localhost:%d"(port));
	assert(req.header["user-agent"] == "hoge");
	Response res;
	res.status = "HTTP/1.1 200 OK";
	res.header["Content-Type"] = "text/plain";
	res.content = "SUCCESS";
	httpd.send(res);
	t.yieldForce();
}

@safe unittest
{
	import std.socket;
	import std.parallelism;
	import std.string;
	import std.range;
	import std.algorithm;
	Httpd httpd;
	httpd.listen();
	ushort port = httpd.listeningPort;
	auto t = task({
		immutable string request = format!`
			GET /test HTTP/1.1
			Host: localhost:%d
			Connection: keep-alive
			User-Agent: hoge
			Accept: text/plain
			Accept-Encoding: gzip, deflate
		`(port).outdent.strip.splitLines.join("\x0d\x0a") ~ "\x0d\x0a\x0d\x0a";
		auto sock = new TcpSocket();
		scope (exit)
			sock.close();
		sock.connect(new InternetAddress("localhost", port));
		foreach (elm; request.representation.chunks(8))
			sock.send(elm);
		import std.array: appender;
		auto response = appender!(string);
		while (sock.isAlive)
		{
			char[1024] recvbuf = void;
			auto recvlen = sock.receive(recvbuf);
			if (recvlen == 0)
				break;
			response ~= recvbuf[0..recvlen];
		}
		auto resLines = response.data.splitLines;
		assert(resLines[0] == "HTTP/1.1 200 OK");
		assert(resLines[1].startsWith("Date: ") && resLines[1].endsWith("GMT"));
		assert(resLines[2] == "Server: httpd");
		assert(resLines[3] == "Content-Length: 7");
		assert(resLines[4] == "Content-Type: text/plain");
		assert(resLines[5] == "Connection: close");
		assert(resLines[6] == "");
		assert(resLines[7] == "SUCCESS");
	});
	t.executeInNewThread();
	Request req;
	auto reqresult = httpd.receive(req, 1000);
	assert(reqresult);
	assert(req.header["host"] == format!"localhost:%d"(port));
	assert(req.header["connection"] == "keep-alive");
	assert(req.header["user-agent"] == "hoge");
	assert(req.header["accept"] == "text/plain");
	assert(req.header["accept-encoding"] == "gzip, deflate");
	Response res;
	res.status = "HTTP/1.1 200 OK";
	res.header["Content-Type"] = "text/plain";
	res.content = "SUCCESS";
	httpd.send(res);
	t.yieldForce();
}

