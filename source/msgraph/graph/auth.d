/*******************************************************************************
 * Authenticate/Authorize helpers
 */
module msgraph.graph.auth;


/*******************************************************************************
 * Auth infomations
 * 
 * - for user application:
 *     https://docs.microsoft.com/ja-jp/graph/auth-v2-user
 * - for service application:
 *     https://docs.microsoft.com/ja-jp/graph/auth-v2-service
 */
struct AuthInfo
{
	/// Tenant ID
	string tenantId;
	/// Client ID
	string clientId;
	/// $(MARK service app only) Client secret
	string clientSecret   = null;
	/// $(MARK native app only)
	string[] requireScope = ["offline_access", "user.read"];
	/// $(MARK native app only)
	string redirectUri    = "https://login.microsoftonline.com/common/oauth2/nativeclient";
	/// $(MARK native app only)
	string responseMode   = "query";
	/// $(MARK native app only)
	string state          = "12345";
	/// $(MARK native app only)
	string accessToken    = null;
	/// $(MARK native app only)
	string refreshToken   = null;
	/// $(MARK native app only)
	void delegate(string url) onAuthCodeRequired = null;
}

/*******************************************************************************
 * $(MARK native app only)
 */
struct InstanceAuthServer
{
private:
	import msgraph.httpd;
	Httpd _httpd;
	string _code;
	string _state;
public:
	
	/***************************************************************************
	 * 
	 */
	void delegate(string code) onAuthCodeAcquired = null;
	
	/***************************************************************************
	 * 
	 */
	void listen()
	{
		_httpd.listen("localhost");
	}
	
	/***************************************************************************
	 * 
	 */
	string endpointUri() const
	{
		import std.conv;
		return "http://localhost:" ~ _httpd.listeningPort.to!string;
	}
	
	/***************************************************************************
	 * 
	 */
	string authCode() const
	{
		return _code;
	}
	
	/***************************************************************************
	 * 
	 */
	bool acceptCode(string state)
	{
		import std.algorithm: canFind;
		import msgraph.graph.httphelper;
		import std.string: chompPrefix, chomp, endsWith, startsWith;
		Request req;
		if (!_httpd.receive(req, 10_000))
			return false;
		auto resParam = req.path.chompPrefix("/?").parseQueryParam();
		_code = resParam.get("code", "");
		if (_code.length == 0
		 || resParam.get("state", "") != state)
		{
			_code = null;
			Response res;
			res.status = "HTTP/1.1 400 Bad Request";
			res.header["Content-Type"] = "text/plain";
			res.content = "FAILED";
			_httpd.send(res);
			return false;
		}
		else
		{
			Response res;
			res.status = "HTTP/1.1 200 OK";
			res.header["Content-Type"] = "text/plain";
			res.content = "SUCCESS";
			_httpd.send(res);
			
			if (onAuthCodeAcquired)
				onAuthCodeAcquired(_code);
		}
		return true;
	}
}
