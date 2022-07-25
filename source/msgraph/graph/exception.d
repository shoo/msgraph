/*******************************************************************************
 * Exception type definitions
 * 
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 */
module msgraph.graph.exception;

import std.exception;
import std.json;

/*******************************************************************************
 * 
 */
mixin template basicGraphExceptionCtors()
{
	/***************************************************************************
	 * 
	 */
	this(string msg, string file = __FILE__, size_t line = __LINE__,
		 Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
	
	/// ditto
	this(string msg, Throwable next, string file = __FILE__,
		 size_t line = __LINE__) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
	
	/// ditto
	this(string msg, JSONValue detail,
		string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
		_detail = detail;
	}
	
	/// ditto
	this(string msg, JSONValue detail, Throwable next,
		string file = __FILE__, size_t line = __LINE__) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
		_detail = detail;
	}
}

/*******************************************************************************
 * 
 */
class GraphException: Exception
{
private:
	JSONValue _detail;
public:
	/***************************************************************************
	 * Params:
	 *      msg    = The message for the exception.
	 *      next   = The previous exception in the chain of exceptions.
	 *      file   = The file where the exception occurred.
	 *      line   = The line number where the exception occurred.
	 *      detail = The detail information with JSON
	 */
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
	
	/// ditto
	this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
	
	/// ditto
	this(string msg, JSONValue detail,
		string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
		_detail = detail;
	}
	
	/// ditto
	this(string msg, JSONValue detail, Throwable next,
		string file = __FILE__, size_t line = __LINE__) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
		_detail = detail;
	}

	/***************************************************************************
	 * 
	 */
	const(JSONValue) detail() const @nogc pure nothrow
	{
		return _detail;
	}
}



/*******************************************************************************
 * 
 */
class AuthorizeException: GraphException
{
	mixin basicGraphExceptionCtors;
}
