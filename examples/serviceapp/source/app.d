import std.stdio;

import msgraph;
import std.process: environment;

void main()
{
	AuthInfo authInfo;
	with (authInfo)
	{
		tenantId = environment.get("GRAPH_TENANT_ID");
		clientId = environment.get("GRAPH_CLIENT_ID");
		clientSecret = environment.get("GRAPH_CLIENT_SECRET");
		requireScope = ["offline_access", "User.Read"];
	}
	auto graph = Graph();
	graph.setup(authInfo);
	
	writeln(graph.users("ad23f694-f1ee-464a-93bf-4a5fdde7ca2a").displayName);
}
