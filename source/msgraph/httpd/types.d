/*******************************************************************************
 * HTTP related types
 */
module msgraph.httpd.types;


package(msgraph):

/*******************************************************************************
 * 
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
 * 
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
