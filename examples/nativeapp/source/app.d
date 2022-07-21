import std.stdio;

import msgraph;
import std.process: environment;

void main()
{
	AuthInfo authInfo;
	with (authInfo)
	{
		tenantId = environment.get("GRAPH_TENANT_ID", "common");
		clientId = environment.get("GRAPH_CLIENT_ID");
		accessToken = environment.get("GRAPH_ACCESS_TOKEN");
		refreshToken = environment.get("GRAPH_REFRESH_TOKEN");
		requireScope = ["offline_access", "User.Read"];
	}
	auto graph = Graph();
	if (authInfo.accessToken is null)
		graph.setupWithInstanceServer(authInfo);
	
	writeln(graph.me.displayName);
}
