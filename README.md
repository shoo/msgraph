# Library of Microsoft Graph for D
[![status](https://github.com/shoo/msgraph/workflows/status/badge.svg)](https://github.com/shoo/msgraph/actions?query=workflow%3Astatus)
[![main](https://github.com/shoo/msgraph/workflows/main/badge.svg)](https://github.com/shoo/msgraph/actions?query=workflow%3Amain)
[![dub](https://img.shields.io/dub/v/msgraph.svg?cacheSeconds=3600)](https://code.dlang.org/packages/msgraph)
[![downloads](https://img.shields.io/dub/dt/msgraph.svg?cacheSeconds=3600)](https://code.dlang.org/packages/msgraph)
[![BSL-1.0](http://img.shields.io/badge/license-BSL--1.0-blue.svg?style=flat)](./LICENSE)
[![codecov](https://codecov.io/gh/shoo/msgraph/branch/main/graph/badge.svg)](https://codecov.io/gh/shoo/msgraph)

This project provides a library to retrieve and manipulate information associated with Office 365 and other accounts through Microsoft Graph.


# Usage
[msgraph's API lists are here](https://shoo.github.io/msgraph/)  
If you are using dub, you can add a dependency by describing it as follows:

```sh
dub add msgraph
```

Or you can add it directly to the project file.

```json
"dependencies": {
    "msgraph": "~>0.0.1",
}
```

## Authorize
There are two ways.
- for native application (ex. windows desktop appliation)
- for service application (ex. web appliation)

### Authorize for native application
In native application, the application obtains permission from the user and accesses information using the user's context. To obtain permission, the user must go through an authentication sequence once in the web browser.
The following code authenticates the user by signing in and granting permission to obtain the information necessary to execute the API.

```d
import msgraph;

void main()
{
	AuthInfo authInfo;
	with (authInfo)
	{
		tenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
		clientId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
		requireScope = ["offline_access", "User.Read"];
	}
	auto graph = Graph();
	graph.setupWithAdHocServer(authInfo);
}
```

The clientId and tenantId are created and obtained by the application developer in [Asure Active Directory](https://azure.microsoft.com/services/active-directory/).

Specifically, the setupWithAdHocServer function does the following:

1. Create a URL based on the client ID and other necessary information, and open a browser with std.process.browse.
2. The user grants login and access rights on the browser.
3. If successful, the browser accesses the local server launched ad hoc by redirection.
4. The redirected query contains an authorize code, which is read.
5. Use the authorization code to obtain an access token.
6. Thereafter, Graph API can be used by communicating with an access token added to the HTTP header.

Thereafter, access tokens can be updated periodically to reduce the need to re-signin, as shown in the following code:

```d
	graph.updateTokens();
```


### Authorize for service application
Service applications access information without the user's permission and by context without the user.
Instead of user permissions, authentication is performed using the client_secret.
The client_secret must be stored securely in a location accessible only to the service administrator. (For this reason, it cannot be used in native applications.)
The following code will authenticate with the client secret and obtain an access token:

```d
import msgraph;

void main()
{
	AuthInfo authInfo;
	with (authInfo)
	{
		tenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
		clientId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
		clientSecret = "xxxxxxxxxxxxxxxxxxxxxxxxx";
	}
	auto graph = Graph(authInfo);
}
```

## Raw query
After obtaining an access token, the API is handled by doing the following:

```d
	import std.json, std.stdio;
	auto res = graph.get("/me/");
	auto userInfo = parseJSON(cast(const(char)[])res.responseBody);
	writeln(userInfo["displayName"].str);
```

The API can be tried in [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer).  
And see also the [reference](https://docs.microsoft.com/graph/api/overview?view=graph-rest-1.0) for details.

# Reference
- [Microsoft Graph API reference](https://docs.microsoft.com/graph/api/overview?view=graph-rest-1.0)
- [Microsoft Graph auth overview](https://docs.microsoft.com/graph/auth/)
- [Use the Microsoft Graph API](https://docs.microsoft.com/graph/use-the-api)
- [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)
- [msgraph's API](https://shoo.github.io/msgraph/)

# Contributing
This project accepts [Issue](https://github.com/shoo/msgraph/issues) reports and [PullRequests](https://github.com/shoo/msgraph/pulls).
The PullRequest must pass all tests in CI of [GitHub Actions](https://github.com/shoo/msgraph/actions).
First, make sure that your environment passes the test with the following commands.

```sh
rdmd scripts/runner.d -m=ut # or dub test
rdmd scripts/runner.d -m=it # or dub build / test / run for all ./testcases/* directories.
```

