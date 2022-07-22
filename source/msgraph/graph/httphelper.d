/*******************************************************************************
 * HTTP helpers
 * 
 * $(INTERNAL_MODULE)
 */
module msgraph.graph.httphelper;

package(msgraph):


/*******************************************************************************
 * $(INTERNAL)
 */
string createQueryParam(string[string] params)
{
	import std.algorithm;
	import std.array;
	import std.string;
	import std.uri;
	string ret;
	foreach (pair; params.byKeyValue.array.sort!((a, b) => icmp(a.key, b.key) < 0))
	{
		if (ret.length != 0)
			ret ~= "&";
		ret ~= encodeComponent(pair.key) ~ "=" ~ encodeComponent(pair.value);
	}
	return ret;
}

/*******************************************************************************
 * $(INTERNAL)
 */
string[string] parseQueryParam(string params)
{
	import std.range;
	import std.algorithm;
	import std.uri;
	string[string] ret;
	foreach (pair; params.split("&"))
	{
		auto kv = pair.split("=");
		ret[decodeComponent(kv.front)] = decodeComponent(kv.back);
	}
	return ret;
}

/*******************************************************************************
 * $(INTERNAL)
 */
string getRandomString(uint length = 0)
{
	import std.random: uniform;
	import std.range: iota, array;
	import std.algorithm: map;
	import std.exception: assumeUnique;
	if (length == 0)
		length = uniform(64, 128);
	static immutable charLut = "abcdefghijklmopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	return iota(0, length).map!(i => charLut[uniform(0, charLut.length)]).array.assumeUnique;
}

