/*******************************************************************************
 * HTTP request parser
 * 
 * $(INTERNAL_MODULE)
 */
module msgraph.httpd.parse;

package(msgraph.httpd):
import msgraph.httpd.types;

/*******************************************************************************
 * $(INTERNAL)
 */
bool parseRequestLine(ref Request req, in char[] buf) @trusted
{
	import std.array: front, back;
	import std.string: strip, split;
	import std.exception: assumeUnique;
	auto requestLine = buf.split(" ");
	if (requestLine.length < 3)
		return false;
	req.method = requestLine.front.strip.assumeUnique;
	req.protocolVersion = requestLine.back.strip.assumeUnique;
	req.path = (cast(char[])buf[req.method.length .. $ - req.protocolVersion.length])
		.strip.assumeUnique;
	return true;
}

@safe unittest
{
	Request req;
	req.parseRequestLine("GET /test HTTP/1.1");
	assert(req.method == "GET");
	assert(req.path == "/test");
	assert(req.protocolVersion == "HTTP/1.1");
}

/*******************************************************************************
 * $(INTERNAL)
 */
bool parseHeaders(ref Request req, in char[] buf) @trusted
{
	import std.array: front, back;
	import std.string: splitLines, toLower, strip;
	import std.algorithm: findSplit;
	import std.exception: assumeUnique;
	foreach (line; splitLines(buf))
	{
		auto linePair = line.findSplit(":");
		if (linePair.length != 3)
			continue;
		req.header[linePair[0].strip.toLower] = linePair[2].strip.assumeUnique;
	}
	return true;
}

@safe unittest
{
	Request req;
	req.parseHeaders("Host: localhost\nContent-Type: text/plain\n");
	assert(req.header.length == 2);
	assert(req.header["host"] == "localhost");
	assert(req.header["content-type"] == "text/plain");
}

/*******************************************************************************
 * $(INTERNAL)
 */
bool parseBody(ref Request req, in char[] buf) @trusted
{
	import std.exception: assumeUnique;
	req.content = buf.assumeUnique;
	return true;
}

@safe unittest
{
	Request req;
	req.parseBody("aaabbbccc");
	assert(req.content.length == 9);
	assert(req.content == "aaabbbccc");
}
