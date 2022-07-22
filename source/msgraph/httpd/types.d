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

/*******************************************************************************
 * $(INTERNAL)
 */
struct Response
{
	///
	string status;
	///
	string[string] header;
	///
	string content;
}
