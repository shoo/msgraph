/*******************************************************************************
 * Microsoft Graph object
 */
module msgraph.graph.graph;

import core.time;
import msgraph.graph.auth;
import msgraph.graph.httphelper;
import msgraph.graph.exception;

/*******************************************************************************
 * 
 */
struct Graph
{
private:
	import etc.c.curl: CurlAuth, CurlOption, CurlProxy;
	import std.net.curl;
	import std.array;
	import std.datetime;
	import std.json;
	import std.string;
	import std.exception;
	
	HTTP   _client;
	string _clientId;
	string _tenantId;
	string _accessToken;
	SysTime _accessTokenExpires;
	string _refreshToken;
	string _clientSecret;
	string _redirectUri;
	string[] _requireScope;
	Appender!(ubyte[]) _contentBuffer;
	debug (MsGraphTest)
	{
		package(msgraph) string[string] _debugUrlReplaceInfo;
	}
	
	void _resetClient(in char[] url, HTTP.Method method)
	{
		_contentBuffer.shrinkTo(0);
		_client.postData = null;
		_client.clearRequestHeaders();
		debug (MsGraphTest)
		{
			string tempUrl = url.idup;
			foreach (k, v; _debugUrlReplaceInfo)
			{
				import std.regex: regex, replaceFirst;
				tempUrl = replaceFirst(tempUrl, regex(k), v);
			}
			_client.url = tempUrl;
		}
		else
		{
			_client.url = url;
		}
		_client.method = method;
		if (_accessToken.length > 0)
			_client.addRequestHeader("Authorization", "Bearer " ~ _accessToken);
	}
	
	void _updateTokensForService()
	{
		enforce!AuthorizeException(_clientSecret.length != 0, "Client secret is not exists.");
		_resetClient(format!"https://login.microsoftonline.com/%s/oauth2/v2.0/token"(_tenantId), HTTP.Method.post);
		auto postData = createQueryParam([
			"client_id": _clientId,
			"scope": "https://graph.microsoft.com/.default",
			"client_secret": _clientSecret,
			"grant_type": "client_credentials"]);
		_client.setPostData(postData, "application/x-www-form-urlencoded");
		_client.perform();
		auto jv = parseJSON(cast(const(char)[])_contentBuffer.data()).ifThrown(JSONValue.init);
		if (_client.statusLine.code != 200)
			throw new AuthorizeException(_client.statusLine.reason, jv);
		_accessToken = jv["access_token"].str;
		_accessTokenExpires = Clock.currTime + jv["expires_in"].integer.seconds;
	}
	
	void _updateTokensForUserApp()
	{
		enforce!AuthorizeException(_refreshToken.length != 0, "Refresh token is not exists.");
		_client.method = HTTP.Method.post;
		_resetClient("https://login.microsoftonline.com/common/oauth2/v2.0/token", HTTP.Method.post);
		auto postData = createQueryParam([
			"client_id": _clientId,
			"scope": _requireScope.join(" "),
			"refresh_token": _refreshToken,
			"redirect_uri": _redirectUri,
			"grant_type": "refresh_token"]);
		_client.setPostData(postData, "application/x-www-form-urlencoded");
		_client.perform();
		
		auto jv = parseJSON(cast(const(char)[])_contentBuffer.data()).ifThrown(JSONValue.init);
		if (_client.statusLine.code != 200)
			throw new AuthorizeException(_client.statusLine.reason, jv);
		_accessToken = jv["access_token"].str;
		_accessTokenExpires = Clock.currTime + jv["expires_in"].integer.seconds;
		if (auto p = "refresh_token" in jv)
			_refreshToken = p.str;
	}
public:
	/***************************************************************************
	 * Copy constructor disabled
	 */
	@disable this(this);
	
	/***************************************************************************
	 * Setup Microsoft Graph
	 * 
	 * Params:
	 *      clientId     = Client ID (from Asure Active Directory)
	 *      tenantId     = Tenant ID (from Asure Active Directory)
	 *      clientSecret = Client secret (from Asure Active Directory, provisioned client secret).  
	 *                     This is set only for server application.
	 *      authInfo     = Detail information for authrization.
	 */
	this(string tenantId, string clientId, string[] requireScope, string clientSecret = null)
	{
		setup(tenantId, clientId, requireScope, clientSecret);
	}
	/// ditto
	this(string tenantId, string clientId, string accessToken, string refreshToken, string[] requireScope)
	{
		setup(tenantId, clientId, accessToken, refreshToken, requireScope);
	}
	/// ditto
	this(AuthInfo authInfo)
	{
		setup(authInfo);
	}
	
	/// ditto
	void setup(string tenantId, string clientId, string[] requireScope, string clientSecret = null)
	{
		AuthInfo info;
		info.tenantId     = tenantId;
		info.clientId     = clientId;
		info.requireScope = requireScope;
		info.clientSecret = clientSecret;
		setup(info);
	}
	
	/// ditto
	void setup(string tenantId, string clientId, string accessToken, string refreshToken, string[] requireScope)
	{
		AuthInfo info;
		info.tenantId     = tenantId;
		info.clientId     = clientId;
		info.requireScope = requireScope;
		info.accessToken  = accessToken;
		info.refreshToken = refreshToken;
		setup(info);
	}
	
	
	/// ditto
	void setup(AuthInfo info)
	{
		import std.process: browse;
		import std.uri: encodeComponent;
		import std.base64: Base64URLNoPadding;
		_client = HTTP();
		_client.onReceive = (ubyte[] buf)
		{
			_contentBuffer ~= buf;
			return buf.length;
		};
		_tenantId = info.tenantId;
		_clientId = info.clientId;
		_redirectUri = info.redirectUri;
		_requireScope = info.requireScope;
		_clientSecret = info.clientSecret;
		if (info.accessToken.length > 0)
		{
			// アクセストークンが指定されている場合
			_accessToken = info.accessToken;
			_refreshToken = info.refreshToken;
			auto accTokJson = parseJSON(cast(string)Base64URLNoPadding.decode(accessToken.split(".")[1]));
			_accessTokenExpires = SysTime.fromUnixTime(accTokJson["exp"].get!ulong, UTC()).toLocalTime();
		}
		else if (info.clientSecret is null)
		{
			// ユーザーアプリケーション向けの認証の仕組みを使用
			// https://docs.microsoft.com/graph/auth-v2-user
			auto state = info.state.length > 0 ? info.state : getRandomString();
			auto url = format!"https://login.microsoftonline.com/%s/oauth2/v2.0/authorize?%s"(_tenantId,
				createQueryParam([
					"client_id": info.clientId,
					"response_type": "code",
					"redirect_uri": _redirectUri,
					"scope": _requireScope.join(" "),
					"response_mode": info.responseMode,
					"state": state,
				]));
			if (info.onAuthCodeRequired !is null)
			{
				return info.onAuthCodeRequired(url);
			}
			else
			{
				return browse(url);
			}
		}
		else
		{
			// サービスアプリケーション向けの認証の仕組みを使用
			// https://docs.microsoft.com/graph/auth-v2-service
			_updateTokensForService();
		}
	}
	
	/***************************************************************************
	 * $(MARK native app only)
	 */
	void authorize(string code)
	{
		_client.method = HTTP.Method.post;
		_resetClient(format!"https://login.microsoftonline.com/%s/oauth2/v2.0/token"(_tenantId), HTTP.Method.post);
		auto postData = createQueryParam([
			"client_id": _clientId,
			"scope": _requireScope.join(" "),
			"code": code,
			"redirect_uri": _redirectUri,
			"grant_type": "authorization_code"]);
		_client.setPostData(postData, "application/x-www-form-urlencoded");
		
		_client.perform();
		auto jv = parseJSON(cast(const(char)[])_contentBuffer.data()).ifThrown(JSONValue.init);
		if (_client.statusLine.code != 200)
			throw new AuthorizeException(_client.statusLine.reason, jv);
		_accessToken = jv["access_token"].str;
		_accessTokenExpires = Clock.currTime + jv["expires_in"].integer.seconds;
		if (auto p = "refresh_token" in jv)
			_refreshToken = p.str;
	}
	
	/***************************************************************************
	 * 
	 */
	void updateTokens()
	{
		if (_refreshToken.length == 0 && _clientSecret.length != 0)
		{
			_updateTokensForService();
		}
		else
		{
			_updateTokensForUserApp();
		}
	}
	
	/***************************************************************************
	 * 
	 */
	string accessToken() const
	{
		return _accessToken;
	}
	
	/***************************************************************************
	 * 
	 */
	SysTime accessTokenExpires() const
	{
		return _accessTokenExpires;
	}
	
	/***************************************************************************
	 * 
	 */
	bool isAccessTokenExpired() const
	{
		return Clock.currTime() > _accessTokenExpires;
	}
	
	/***************************************************************************
	 * $(MARK native app only)
	 */
	string refreshToken() const
	{
		return _refreshToken;
	}
	
	/***************************************************************************
	 * 
	 */
	alias Method = HTTP.Method;
	
	/***************************************************************************
	 * 
	 */
	enum Endpoint: string
	{
		///
		v1_0 = "https://graph.microsoft.com/v1.0",
		/// ditto
		v1 = v1_0,
		///
		beta = "https://graph.microsoft.com/beta"
	}
	
	/***************************************************************************
	 * 
	 */
	struct HttpResult
	{
		///
		HTTP.StatusLine statusLine;
		///
		string[string] responseHeaders;
		///
		immutable(ubyte)[] responseBody;
	}
	
	/***************************************************************************
	 * 
	 */
	ref inout(HTTP) handle() inout return
	{
		return _client;
	}
	
	/***************************************************************************
	 * Set proxy settings
	 * 
	 * Params:
	 *      proxy     = Hostname or URL
	 *      port      = Port number
	 *      proxyType = Type of proxy
	 *      authUser  = User name for proxy
	 *      authPass  = Password for proxy
	 *      authType  = Auth type of proxy
	 */
	void setProxy(string proxy)
	{
		_client.proxy = proxy;
	}
	
	/// ditto
	void setProxy(string proxy, ushort port, CurlProxy proxyType = CurlProxy.http)
	{
		_client.proxy = proxy;
		_client.proxyPort = port;
		_client.proxyType = proxyType;
	}
	
	/// ditto
	void setProxy(string proxy, string authUser, string authPass, CurlAuth authType = CurlAuth.basic)
	{
		_client.proxy = proxy;
		_client.setProxyAuthentication(authUser, authPass);
		_client.handle.set(CurlOption.proxyauth, authType);
	}
	
	/// ditto
	void setProxy(string proxy, ushort port,
		string authUser, string authPass,
		CurlProxy proxyType = CurlProxy.http, CurlAuth authType = CurlAuth.basic)
	{
		_client.proxy = proxy;
		_client.proxyPort = port;
		_client.proxyType = proxyType;
		_client.setProxyAuthentication(authUser, authPass);
		_client.handle.set(CurlOption.proxyauth, authType);
	}
	
	/***************************************************************************
	 * Certification settings
	 * 
	 * Params:
	 *      cafile             = PEM file of trusted CA.
	 *      clientCertFile     = PEM file of client cert file if required.
	 *      privateKeyFile     = PEM file of client private key file if required.
	 *      privateKeyPassword = Password of private key file if required.
	 */
	void setCert(in char[] cafile,
		in char[] clientCertFile = null, in char[] privateKeyFile = null, in char[] privateKeyPassword = null)
	{
		_client.caInfo(cafile);
		if (clientCertFile.length > 0)
		{
			_client.handle.set(CurlOption.sslcerttype, "PEM");
			_client.handle.set(CurlOption.sslcert, clientCertFile);
			if (privateKeyFile.length > 0)
			{
				_client.handle.set(CurlOption.sslkeytype, "PEM");
				_client.handle.set(CurlOption.sslkey, privateKeyFile);
			}
			if (privateKeyPassword.length > 0)
				_client.handle.set(CurlOption.keypasswd, privateKeyPassword);
		}
	}
	
	/***************************************************************************
	 * HTTP Request for Microsoft Graph API call
	 */
	HttpResult request(Method method, Endpoint endpoint, in char[] resource, in char[] query,
		in ubyte[] contents = null, string contentType = null)
	{
		import std.string: chompPrefix;
		import std.exception: assumeUnique;
		HttpResult ret;
		auto url = endpoint ~ "/"
			~ resource.chompPrefix("/")
			~ (query.length > 0 ? ("?" ~ query.chompPrefix("?")) : null);
		_resetClient(url, method);
		if (contents.length)
			_client.setPostData(contents, contentType);
		_client.perform();
		ret.statusLine = _client.statusLine;
		ret.responseHeaders = _client.responseHeaders;
		ret.responseBody = _contentBuffer.data.assumeUnique;
		return ret;
	}
	
	/***************************************************************************
	 * GET Request
	 */
	HttpResult get(in char[] resource, in char[] query)
	{
		return request(Method.get, Endpoint.v1, resource, query, null, null);
	}
	/// ditto
	HttpResult get(string resource, string[string] query)
	{
		return request(Method.get, Endpoint.v1, resource, query.createQueryParam(), null, null);
	}
	/// ditto
	HttpResult get(string resource)
	{
		return request(Method.get, Endpoint.v1, resource, null, null, null);
	}
	
	/***************************************************************************
	 * POST Request
	 */
	HttpResult post(in char[] resource, in ubyte[] contents, string contentType = "application/octet-stream")
	{
		return request(Method.post, Endpoint.v1, resource, null, contents, contentType);
	}
	/// ditto
	HttpResult post(in char[] resource, in char[] contents, string contentType = "application/x-www-form-urlencoded")
	{
		return request(Method.post, Endpoint.v1, resource, null, contents.representation, contentType);
	}
	/// ditto
	HttpResult post(in char[] resource, JSONValue params)
	{
		return post(resource, params.toString(), "application/json");
	}
	/// ditto
	HttpResult post(in char[] resource, string[string] params)
	{
		return post(resource, params.createQueryParam(), "application/x-www-form-urlencoded");
	}
	
	/***************************************************************************
	 * PUT Request
	 */
	HttpResult put(in char[] resource, in ubyte[] contents, string contentType = "application/octet-stream")
	{
		return request(Method.put, Endpoint.v1, resource, null, contents, contentType);
	}
	/// ditto
	HttpResult put(in char[] resource, in char[] contents, string contentType = "application/x-www-form-urlencoded")
	{
		return request(Method.put, Endpoint.v1, resource, null, contents.representation, contentType);
	}
	/// ditto
	HttpResult put(in char[] resource, JSONValue params)
	{
		return put(resource, params.toString(), "application/json");
	}
	/// ditto
	HttpResult put(in char[] resource, string[string] params)
	{
		return put(resource, params.createQueryParam(), "application/x-www-form-urlencoded");
	}
	
	/***************************************************************************
	 * PATCH Request
	 */
	HttpResult patch(in char[] resource, in ubyte[] contents, string contentType = "application/octet-stream")
	{
		return request(Method.patch, Endpoint.v1, resource, null, contents, contentType);
	}
	/// ditto
	HttpResult patch(in char[] resource, in char[] contents, string contentType = "application/x-www-form-urlencoded")
	{
		return request(Method.patch, Endpoint.v1, resource, null, contents.representation, contentType);
	}
	/// ditto
	HttpResult patch(in char[] resource, JSONValue params)
	{
		return patch(resource, params.toString(), "application/json");
	}
	/// ditto
	HttpResult patch(in char[] resource, string[string] params)
	{
		return patch(resource, params.createQueryParam(), "application/x-www-form-urlencoded");
	}
	
	/***************************************************************************
	 * DELETE Request
	 */
	HttpResult del(in char[] resource)
	{
		return request(Method.del, Endpoint.v1, resource, null, null, null);
	}
}

/*******************************************************************************
 * $(MARK native app only)
 */
bool setupWithInstanceServer(ref Graph g, AuthInfo authInfo, Duration dur = 30.seconds)
{
	import std.process: browse;
	InstanceAuthServer authServer;
	bool ret;
	
	authInfo.state = getRandomString();
	authInfo.onAuthCodeRequired = (string url)
	{
		browse(url);
		if (authServer.acceptCode(authInfo.state))
			ret = true;
	};
	authServer.onAuthCodeAcquired = &g.authorize;
	authServer.listen();
	authInfo.redirectUri = authServer.endpointUri;
	g.setup(authInfo);
	return ret;
}

@system unittest
{
	import std.process: browse;
	import std.parallelism: task;
	import std.net.curl: get;
	import std.conv: text;
	import msgraph.httpd: Httpd, Request, Response;
	InstanceAuthServer authServer;
	bool ret;
	AuthInfo authInfo;
	Graph g;
	
	with (authInfo)
	{
		tenantId = "testtenant";
		clientId = "testclient";
	}
	authInfo.state = getRandomString();
	auto t = task({
		get(authServer.endpointUri ~ "/?code=testcode&state=" ~ authInfo.state);
	});
	authInfo.onAuthCodeRequired = (string url)
	{
		t.executeInNewThread();
		if (authServer.acceptCode(authInfo.state))
			ret = true;
	};
	authServer.onAuthCodeAcquired = &g.authorize;
	authServer.listen();
	authInfo.redirectUri = authServer.endpointUri;
	Httpd httpd;
	httpd.listen();
	g._debugUrlReplaceInfo = ["https://login.microsoftonline.com": "http://localhost:".text(httpd.listeningPort)];
	auto t2 = task({
		Request req;
		httpd.receive(req, 1000);
		Response res;
		res.status = "HTTP/1.1 200 OK";
		res.header["Content-Type"] = "application/json";
		res.content = `{"access_token": "testacctoken", "refresh_token": "testreftoken", "expires_in": 12345}`;
		httpd.send(res);
	});
	t2.executeInNewThread();
	g.setup(authInfo);
	t.yieldForce();
	t2.yieldForce();
	assert(ret);
	assert(g.accessToken == "testacctoken");
	assert(g.refreshToken == "testreftoken");
}


@system unittest
{
	import std.conv: text;
	import std.base64;
	import std.parallelism: task;
	import std.json;
	import std.string;
	import msgraph.httpd;
	auto acctok = ("acctok."
		~ Base64URLNoPadding.encode(JSONValue(["exp": 12345]).toString.representation)
		~ ".test").idup;
	auto g = Graph("testtenant", "testclient", acctok, null, []);
	auto httpd = Httpd();
	httpd.listen();
	auto t2 = task({
		Request req;
		httpd.receive(req, 1000);
		assert(req.path == "/v1.0/me/");
		assert(req.header["authorization"] == "Bearer " ~ acctok);
		Response res;
		res.status = "HTTP/1.1 200 OK";
		res.header["Content-Type"] = "application/json";
		res.content = `{}`;
		httpd.send(res);
	});
	g._debugUrlReplaceInfo = ["https://graph.microsoft.com": "http://localhost:".text(httpd.listeningPort)];
	t2.executeInNewThread();
	auto res = g.get("/me/");
	assert(cast(const char[])res.responseBody == "{}");
	t2.yieldForce();
}
