import std.file, std.path, std.process, std.stdio;

int main()
{
	immutable dubExe = environment.get("$DUB", "dub");
	foreach (de; dirEntries("../examples", SpanMode.depth))
	{
		if (de.name.isDubProject())
		{
			auto pid = spawnProcess([dubExe, "build"], stdin, stdout, stderr, null, Config.none, de.name.absolutePath);
			auto res = pid.wait();
			if (res != 0)
				return res;
		}
	}
	return 0;
}

///
bool isDubProject(string name)
{
	if (!name.exists || !name.isDir)
		return false;
	if (name.buildPath("dub.json").exists)
		return true;
	if (name.buildPath("dub.sdl").exists)
		return true;
	return false;
}
