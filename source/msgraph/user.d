/*******************************************************************************
 * User informations
 * 
 * License: [BSL-1.0](http://boost.org/LICENSE_1_0.txt).
 */
module msgraph.user;

import msgraph.graph;
import msgraph.graph.jsonhelper;
import std.json;

/*******************************************************************************
 * User
 * 
 * https://docs.microsoft.com/ja-jp/graph/api/user-get?view=graph-rest-1.0&tabs=http
 */
struct User
{
	///
	string[] businessPhones;
	///
	string displayName;
	///
	string givenName;
	///
	string jobTitle;
	///
	string mail;
	///
	string mobilePhone;
	///
	string officeLocation;
	///
	string preferredLanguage;
	///
	string surname;
	///
	string userPrincipalName;
	///
	string id;
}

/*******************************************************************************
 * 
 */
User me(ref Graph g)
{
	User ret;
	ret.deserializeFromJsonString(cast(string)g.get("/me/").responseBody);
	return ret;
}


/*******************************************************************************
 * 
 */
User users(ref Graph g, string userId)
{
	import std.format;
	User ret;
	ret.deserializeFromJsonString(cast(string)g.get(format!"/users/%s/"(userId)).responseBody);
	return ret;
}
