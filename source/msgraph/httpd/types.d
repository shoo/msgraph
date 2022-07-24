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
	this(HttpStatusLine sts, in ubyte[] data, string contentType) @safe
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

