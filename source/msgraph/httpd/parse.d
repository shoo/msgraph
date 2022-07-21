/*******************************************************************************
 * HTTP request parser
 */
module msgraph.httpd.parse;

package(msgraph.httpd):
import msgraph.httpd.types;

/*******************************************************************************
 * 
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

/*******************************************************************************
 * 
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

/*******************************************************************************
 * 
 */
bool parseBody(ref Request req, in char[] buf) @trusted
{
	import std.exception: assumeUnique;
	req.content = buf.assumeUnique;
	return true;
}
