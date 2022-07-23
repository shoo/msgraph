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
string createQueryParam(string[string] params) @safe
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

/// 
@safe unittest
{
	auto q = createQueryParam(["aaa": "xxx", "ccc": "zzz", "bbb": "yyy"]);
	assert(q == "aaa=xxx&bbb=yyy&ccc=zzz");
}

/*******************************************************************************
 * $(INTERNAL)
 */
string[string] parseQueryParam(string params) @safe
{
	import std.range;
	import std.algorithm;
	import std.uri;
	string[string] ret;
	foreach (pair; params.split("&"))
	{
		auto kv = pair.split("=");
		if (kv.length == 0)
			continue;
		ret[decodeComponent(kv.front)] = decodeComponent(kv.back);
	}
	return ret;
}
/// 
@safe unittest
{
	auto q = parseQueryParam("aaa=xxx&bbb=yyy&ccc=zzz");
	assert(q.length == 3);
	assert(q["aaa"] == "xxx");
	assert(q["bbb"] == "yyy");
	assert(q["ccc"] == "zzz");
}
@safe unittest
{
	auto q = parseQueryParam("aaa=xxx&bbb=yyy&ccc=zzz&");
	assert(q.length == 3);
	assert(q["aaa"] == "xxx");
	assert(q["bbb"] == "yyy");
	assert(q["ccc"] == "zzz");
}

/*******************************************************************************
 * $(INTERNAL)
 */
string getRandomString(uint length = 0) @safe
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
/// 
@safe unittest
{
	auto q1 = getRandomString();
	auto q2 = getRandomString();
	auto q3 = getRandomString(32);
	assert(q1.length >= 64 && q1.length < 128);
	assert(q2.length >= 64 && q2.length < 128);
	assert(q1 != q2);
	assert(q3.length == 32);
	assert(q1 != q3);
	assert(q2 != q3);
}

