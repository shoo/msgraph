/*******************************************************************************
 * HTTP related types
 * 
 * $(INTERNAL_MODULE)
 */
module msgraph.httpd.types;


package(msgraph):

/*******************************************************************************
 * $(INTERNAL)
 */
struct Request
{
	///
	string method;
	///
	string path;
	///
	string protocolVersion;
	///
	string[string] header;
	///
	string content;
}


enum HttpStatusLine: string
{
	ok = "HTTP/1.1 200 OK",
	badRequest = "HTTP/1.1 400 Bad Request",
}

/*******************************************************************************
 * $(INTERNAL)
 */
struct Response
{
	import std.json;
	///
	HttpStatusLine status;
	///
	string[string] header;
	///
	const(ubyte)[] content;
	
	///
	this(HttpStatusLine sts, string[string] hdr, in ubyte[] data) @safe
	{
		status  = sts;
		header  = hdr;
		content = data;
	}
	
	///
	this(HttpStatusLine sts, string[string] hdr, in char[] data) @safe
	{
		import std.string: representation;
		status  = sts;
		header  = hdr;
		content = data.representation;
	}
	
	/// ditto
	this(HttpStatusLine sts, in ubyte[] data, string contentType = "application/octet-stream") @safe
	{
		status  = sts;
		header  = ["Content-Type": contentType];
		content = data;
	}
	
	/// ditto
	this(HttpStatusLine sts, in char[] data, string contentType = "text/plain") @safe
	{
		import std.string: representation;
		status  = sts;
		header  = ["Content-Type": contentType];
		content = data.representation;
	}
	
	/// ditto
	this(HttpStatusLine sts, in JSONValue data, string contentType = "application/json") @safe
	{
		import std.string: representation;
		status  = sts;
		header  = ["Content-Type": contentType];
		content = data.toString().representation;
	}
}

@safe unittest
{
	import std.string, std.json;
	auto res1 = Response(HttpStatusLine.ok, ["Content-Type": "text/plain"], "aaa".representation);
	auto res2 = Response(HttpStatusLine.ok, ["Content-Type": "text/plain"], "aaa");
	assert(res1 == res2);
	auto res3 = Response(HttpStatusLine.ok, "aaa");
	assert(res3.content == "aaa".representation);
	assert(res3.header["Content-Type"] == "text/plain");
	auto res4 = Response(HttpStatusLine.ok, "aaa".representation);
	assert(res4.content == "aaa".representation);
	assert(res4.header["Content-Type"] == "application/octet-stream");
	auto res5 = Response(HttpStatusLine.ok, JSONValue(["a": "b"]));
	assert(res5.content == `{"a":"b"}`.representation);
	assert(res5.header["Content-Type"] == "application/json");
}
