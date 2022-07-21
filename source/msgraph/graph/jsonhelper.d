/*******************************************************************************
 * JSON Helpers
 */
module msgraph.graph.jsonhelper;

version (have_voile)
{
	public import voile.attr:
		essential,
		ignore,
		name,
		convBy,
		convertFrom,
		convertTo;
	public import voile.json:
		getValue,
		setValue,
		deserializeFromJson,
		deserializeFromJsonString,
		serializeToJson,
		serializeToJsonString;
}
else:

import std.traits;
import std.meta;

//##############################################################################
//####### from voile.misc
//##############################################################################
private:

/*******************************************************************************
 * 
 */
auto ref assumeAttr(alias fn, alias attrs, Args...)(auto ref Args args)
if (isFunction!fn)
{
	alias Func = SetFunctionAttributes!(typeof(&fn), functionLinkage!fn, attrs);
	return (cast(Func)&fn)(args);
}

/// ditto
auto ref assumeAttr(alias fn, alias attrs, Args...)(auto ref Args args)
if (__traits(isTemplate, fn) && isCallable!(fn!Args))
{
	return (cast(Func)&fn!Args)(args);
}

/// ditto
auto assumeAttr(alias attrs, Fn)(Fn t)
	if (isFunctionPointer!Fn || isDelegate!Fn)
{
	return cast(SetFunctionAttributes!(Fn, functionLinkage!Fn, attrs)) t;
}

/*******************************************************************************
 * 
 */
template getFunctionAttributes(T...)
{
	alias fn = T[0];
	static if (T.length == 1 && (isFunctionPointer!(T[0]) || isDelegate!(T[0])))
	{
		enum getFunctionAttributes = functionAttributes!fn;
	}
	else static if (!is(typeof(fn!(T[1..$]))))
	{
		enum getFunctionAttributes = functionAttributes!(fn);
	}
	else
	{
		enum getFunctionAttributes = functionAttributes!(fn!(T[1..$]));
	}
}

/*******************************************************************************
 * 
 */
auto ref assumePure(alias fn, Args...)(auto ref Args args)
{
	return assumeAttr!(fn, getFunctionAttributes!(fn, Args) | FunctionAttribute.pure_, Args)(args);
}

/// ditto
auto assumePure(T)(T t)
	if (isFunctionPointer!T || isDelegate!T)
{
	return assumeAttr!(getFunctionAttributes!T | FunctionAttribute.pure_)(t);
}

//##############################################################################
//####### from voile.attr
//##############################################################################

// from phobos private template in std.traits
template isDesiredUDA(alias attribute)
{
	template isDesiredUDA(alias toCheck)
	{
		static if (is(typeof(attribute)) && !__traits(isTemplate, attribute))
		{
			static if (__traits(compiles, toCheck == attribute))
				enum isDesiredUDA = toCheck == attribute;
			else
				enum isDesiredUDA = false;
		}
		else static if (is(typeof(toCheck)))
		{
			static if (__traits(isTemplate, attribute))
				enum isDesiredUDA =  isInstanceOf!(attribute, typeof(toCheck));
			else
				enum isDesiredUDA = is(typeof(toCheck) == attribute);
		}
		else static if (__traits(isTemplate, attribute))
			enum isDesiredUDA = isInstanceOf!(attribute, toCheck);
		else
			enum isDesiredUDA = is(toCheck == attribute);
	}
}

/*******************************************************************************
 * 関数のパラメータに付与されたUDAを取り出す。
 * 
 * Params:
 *      Func = 関数
 *      i    = 引数の番号(最初の引数は0番目)
 *      attr = UDAの種類を指定できます(指定しないとすべて返します)
 * Returns:
 *      UDAのタプルが返ります
 */
template getParameterUDAs(alias Func, size_t i)
{
	static if (__traits(compiles, { static assert(__traits(getAttributes, Parameters!Func[i]).length > 0); }))
	{
		alias getParameterUDAs = __traits(getAttributes, Parameters!Func[i]);
	}
	else static if (__traits(compiles, __traits(getAttributes, Parameters!Func[i..i+1])))
	{
		alias getParameterUDAs = __traits(getAttributes, Parameters!Func[i..i+1]);
	}
	else
	{
		alias getParameterUDAs = AliasSeq!();
	}
}
/// ditto
alias getParameterUDAs(alias Func, size_t i, alias attr) = Filter!(isDesiredUDA!attr, getParameterUDAs!(Func, i));

/*******************************************************************************
 * 関数のパラメータに付与されたUDAのうち、型についたUDAを取り出す。
 * 
 * Params:
 *      Func = 関数
 *      i    = 引数の番号(最初の引数は0番目)
 *      attr = UDAの種類を指定できます(指定しないとすべて返します)
 * Returns:
 *      UDAのタプルが返ります
 */
template getParameterTypeUDAs(alias Func, size_t i)
{
	static if (__traits(compiles, __traits(getAttributes, Parameters!Func[i])))
	{
		alias getParameterTypeUDAs = __traits(getAttributes, Parameters!Func[i]);
	}
	else
	{
		alias getParameterTypeUDAs = AliasSeq!();
	}
}
/// ditto
alias getParameterTypeUDAs(alias Func, size_t i, alias attr)
	= Filter!(isDesiredUDA!attr, getParameterTypeUDAs!(Func, i));


/*******************************************************************************
 * 関数のパラメータに付与されたUDAのうち、引数についたUDAを取り出す。
 * 
 * Params:
 *      Func = 関数
 *      i    = 引数の番号(最初の引数は0番目)
 *      attr = UDAの種類を指定できます(指定しないとすべて返します)
 * Returns:
 *      UDAのタプルが返ります
 */
template getParameterArgUDAs(alias Func, size_t i)
{
	enum bool notFoundInType(alias val) = staticIndexOf!(val, getParameterTypeUDAs!(Func, i)) == -1;
	alias getParameterArgUDAs = Filter!(notFoundInType, getParameterUDAs!(Func, i));
}
/// ditto
alias getParameterArgUDAs(alias Func, size_t i, alias attr) = Filter!(isDesiredUDA!attr, getParameterArgUDAs!(Func, i));



/*******************************************************************************
 * 関数のパラメータにUDAが付与されているか確認します
 * 
 * Params:
 *      Func = 関数
 *      i    = 引数の番号(最初の引数は0番目)
 *      attr = チェックするUDA
 * Returns:
 *      UDAがあったらtrue
 */
enum bool hasParameterUDA(alias Func, size_t i, alias attr) = getParameterUDAs!(Func, i, attr).length != 0;


/*******************************************************************************
 * 関数のパラメータに付与されたUDAのうち、型にUDAがついているか確認します
 * 
 * Params:
 *      Func = 関数
 *      i    = 引数の番号(最初の引数は0番目)
 *      attr = チェックするUDA
 * Returns:
 *      UDAがあったらtrue
 */
enum bool hasParameterTypeUDA(alias Func, size_t i, alias attr) = getParameterTypeUDAs!(Func, i, attr).length != 0;


/*******************************************************************************
 * 関数のパラメータに付与されたUDAのうち、引数にUDAがついているか確認します
 * 
 * Params:
 *      Func = 関数
 *      i    = 引数の番号(最初の引数は0番目)
 *      attr = チェックするUDA
 * Returns:
 *      UDAがあったらtrue
 */
enum bool hasParameterArgUDA(alias Func, size_t i, alias attr) = getParameterArgUDAs!(Func, i, attr).length != 0;

enum Ignore {init}

/*******************************************************************************
 * Attribute marking ignore data
 */
public enum Ignore ignore = Ignore.init;

///
enum bool hasIgnore(alias value) = hasUDA!(value, Ignore);

enum Essential {init}

/*******************************************************************************
 * Attribute marking essential field
 */
public enum Essential essential = Essential.init;

///
enum bool hasEssential(alias value) = hasUDA!(value, Essential);


struct Name
{
	string name;
}

/*******************************************************************************
 * Attribute forcing field name
 */
public Name name(string name) pure nothrow @nogc @safe
{
	return Name(name);
}
/// ditto
public enum Name name(string n) = Name(n);

///
enum bool hasName(alias value) = hasUDA!(value, Name);

///
template getName(alias value)
if (hasName!value)
{
	enum string getName = getUDAs!(value, Name)[0].name;
}

///
struct ConvBy(alias T){}

///
public alias convBy = ConvBy;

///
template isConvByAttr(alias Attr)
{
	static if (isInstanceOf!(convBy, Attr))
	{
		enum bool isConvByAttr = true;
	}
	else static if (is(typeof(Attr.to)) && is(typeof(Attr.from)))
	{
		enum bool isConvByAttr = true;
	}
	else
	{
		enum bool isConvByAttr = false;
	}
}

///
template getConvByAttr(alias Attr)
if (isConvByAttr!Attr)
{
	static if (isInstanceOf!(convBy, Attr))
	{
		alias getConvByAttr = TemplateArgsOf!(Attr)[0];
	}
	else static if (is(typeof(Attr.to)) && is(typeof(Attr.from)))
	{
		alias getConvByAttr = Attr;
	}
	else static assert(0);
}


///
alias ProxyList(alias value) = staticMap!(getConvByAttr, Filter!(isConvByAttr, __traits(getAttributes, value)));

///
template getConvBy(alias value)
{
	private alias _list = ProxyList!value;
	static assert(_list.length <= 1, `Only single serialization proxy is allowed`);
	alias getConvBy = _list[0];
}

///
template hasConvBy(alias value)
{
	private enum _listLength = ProxyList!value.length;
	static assert(_listLength <= 1, `Only single serialization proxy is allowed`);
	enum bool hasConvBy = _listLength == 1;
}


enum ConvStyle
{
	none,
	type1, // Ret dst = proxy.to(value);        / Val dst = proxy.from(value);
	type2, // Ret dst = proxy.to!Ret(value);    / Val dst = proxy.from!Val(value);
	type3, // Ret dst; proxy.to(value, dst);    / Val dst; proxy.from(value, dst);
	type4, // Ret dst = proxy(value);           / Val dst = proxy(value);
	type5, // Ret dst = proxy!Ret(value);       / Val dst = proxy!Val(value);
	type6, // Ret dst; proxy(value, dst);       / Val dst; proxy(value, dst);
}

template getConvToStyle(alias value, Ret)
if (hasConvBy!value)
{
	alias proxy = getConvBy!value;
	alias Val   = typeof(value);
	static if (is(typeof(proxy.to(lvalueOf!Val)) : Ret))
	{
		// Ret dst = proxy.to(value);
		enum getConvToStyle = ConvStyle.type1;
	}
	else static if (is(typeof(proxy.to!Ret(lvalueOf!Val)) : Ret))
	{
		// Ret dst = proxy.to!Ret(value);
		enum getConvToStyle = ConvStyle.type2;
	}
	else static if (is(typeof(proxy.to(lvalueOf!Val, lvalueOf!Ret)))
	            && !is(typeof(proxy.to(lvalueOf!Val, rvalueOf!Ret))))
	{
		// Ret dst; proxy.to(value, dst);
		enum getConvToStyle = ConvStyle.type3;
	}
	else static if (is(typeof(proxy(lvalueOf!Val)) : Ret))
	{
		// Ret dst = proxy(value);
		enum getConvToStyle = ConvStyle.type4;
	}
	else static if (is(typeof(proxy!Ret(lvalueOf!Val)) : Ret))
	{
		// Ret dst = proxy!Ret(value);
		enum getConvToStyle = ConvStyle.type5;
	}
	else static if (is(typeof(proxy(lvalueOf!Val, lvalueOf!Ret)))
	            && !is(typeof(proxy(lvalueOf!Val, rvalueOf!Ret))))
	{
		// Ret dst; proxy(value, dst);
		enum getConvToStyle = ConvStyle.type6;
	}
	else
	{
		// no match
		enum getConvToStyle = ConvStyle.none;
	}
}

///
template canConvTo(alias value, T)
{
	static if (hasConvBy!value)
	{
		enum bool canConvTo = getConvToStyle!(value, T) != ConvStyle.none;
	}
	else
	{
		enum bool canConvTo = false;
	}
}


///
template convTo(alias value, Dst)
if (canConvTo!(value, Dst))
{
	alias proxy = getConvBy!value;
	alias Val   = typeof(value);
	enum convToStyle = getConvToStyle!(value, Dst);
	static if (convToStyle == ConvStyle.type1)
	{
		static Dst convTo()(auto ref Val v)
		{
			return proxy.to(v);
		}
		static Dst convTo()(in auto ref Val v)
		{
			return proxy.to(v);
		}
	}
	else static if (convToStyle == ConvStyle.type2)
	{
		static Dst convTo()(auto ref Val v)
		{
			return proxy.to!Dst(v);
		}
		static Dst convTo()(in auto ref Val v)
		{
			return proxy.to!Dst(v);
		}
	}
	else static if (convToStyle == ConvStyle.type3)
	{
		static Dst convTo()(auto ref Val v)
		{
			Dst dst = void; proxy.to(v, dst); return dst;
		}
		static Dst convTo()(in auto ref Val v)
		{
			Dst dst = void; proxy.to(v, dst); return dst;
		}
	}
	else static if (convToStyle == ConvStyle.type4)
	{
		static Dst convTo()(auto ref Val v)
		{
			return proxy(v);
		}
		static Dst convTo()(in auto ref Val v)
		{
			return proxy(v);
		}
	}
	else static if (convToStyle == ConvStyle.type5)
	{
		static Dst convTo()(auto ref Val v)
		{
			return proxy!Dst(v);
		}
		static Dst convTo()(in auto ref Val v)
		{
			return proxy!Dst(v);
		}
	}
	else static if (convToStyle == ConvStyle.type6)
	{
		static Dst convTo()(auto ref Val v)
		{
			Dst dst = void; proxy(v, dst); return dst;
		}
		static Dst convTo()(in auto ref Val v)
		{
			Dst dst = void; proxy(v, dst); return dst;
		}
	}
	else static assert(0);
}

///
template getConvFromStyle(alias value, Src)
if (hasConvBy!value)
{
	alias proxy = getConvBy!value;
	alias Val   = typeof(value);
	static if (is(typeof(proxy.from(lvalueOf!Src)) : Val))
	{
		// Val dst = proxy.from(value);
		enum getConvFromStyle = ConvStyle.type1;
	}
	else static if (is(typeof(proxy.from!Val(lvalueOf!Src)) : Val))
	{
		// Val dst = proxy.from!Val(value);
		enum getConvFromStyle = ConvStyle.type2;
	}
	else static if (is(typeof(proxy.from(lvalueOf!Src, lvalueOf!Val)))
	            && !is(typeof(proxy.from(lvalueOf!Src, rvalueOf!Val))))
	{
		// Val dst; proxy.from(value, dst);
		enum getConvFromStyle = ConvStyle.type3;
	}
	else static if (is(typeof(proxy(lvalueOf!Src)) : Val))
	{
		// Val dst = proxy(value);
		enum getConvFromStyle = ConvStyle.type4;
	}
	else static if (is(typeof(proxy!Val(lvalueOf!Src)) : Val))
	{
		// Val dst = proxy!Val(value);
		enum getConvFromStyle = ConvStyle.type5;
	}
	else static if (is(typeof(proxy(lvalueOf!Src, lvalueOf!Val)))
	            && !is(typeof(proxy(lvalueOf!Src, rvalueOf!Val))))
	{
		// Val dst; proxy(value, dst);
		enum getConvFromStyle = ConvStyle.type6;
	}
	else
	{
		// no match
		enum getConvFromStyle = ConvStyle.none;
	}
}

///
template canConvFrom(alias value, T)
{
	static if (hasConvBy!value) {
		enum bool canConvFrom = getConvFromStyle!(value, T) != ConvStyle.none;
	}
	else
	{
		enum bool canConvFrom = false;
	}
}

///
template convFrom(alias value, Src)
if (canConvFrom!(value, Src))
{
	alias proxy = getConvBy!value;
	alias Val   = typeof(value);
	enum convFromStyle = getConvFromStyle!(value, Src);
	static if (convFromStyle == ConvStyle.type1)
	{
		static Val convFrom()(auto ref Src v)
		{
			return proxy.from(v);
		}
		static Val convFrom()(in auto ref Src v)
		{
			return proxy.from(v);
		}
	}
	else static if (convFromStyle == ConvStyle.type2)
	{
		static Val convFrom()(auto ref Src v)
		{
			return proxy.from!Val(v);
		}
		static Val convFrom()(in auto ref Src v)
		{
			return proxy.from!Val(v);
		}
	}
	else static if (convFromStyle == ConvStyle.type3)
	{
		static Val convFrom()(auto ref Src v)
		{
			Val dst = void; proxy.from(v, dst); return dst;
		}
		static Val convFrom()(in auto ref Src v)
		{
			Val dst = void; proxy.from(v, dst); return dst;
		}
	}
	else static if (convFromStyle == ConvStyle.type4)
	{
		static Val convFrom()(auto ref Src v)
		{
			return proxy(v);
		}
		static Val convFrom()(in auto ref Src v)
		{
			return proxy(v);
		}
	}
	else static if (convFromStyle == ConvStyle.type5)
	{
		static Val convFrom()(auto ref Src v)
		{
			return proxy!Val(v);
		}
		static Val convFrom()(in auto ref Src v)
		{
			return proxy!Val(v);
		}
	}
	else static if (convFromStyle == ConvStyle.type6)
	{
		static Val convFrom()(auto ref Src v)
		{
			Val dst = void;
			proxy(v, dst);
			return dst;
		}
		static Val convFrom()(in auto ref Src v)
		{
			Val dst = void;
			proxy(v, dst);
			return dst;
		}
	}
	else static assert(0);
}

///
public template convertTo(alias value)
{
	alias proxy = getConvBy!value;
	alias Val   = typeof(value);
	static void convertTo(Dst)(auto ref Val src, ref Dst dst)
	if (canConvTo!(value, Dst))
	{
		enum convToStyle = getConvToStyle!(value, Dst);
		static if (convToStyle == ConvStyle.type1)
		{
			dst = proxy.to(src);
		}
		else static if (convToStyle == ConvStyle.type2)
		{
			dst = proxy.to!Dst(src);
		}
		else static if (convToStyle == ConvStyle.type3)
		{
			proxy.to(src, dst);
		}
		else static if (convToStyle == ConvStyle.type4)
		{
			dst = proxy(src);
		}
		else static if (convToStyle == ConvStyle.type5)
		{
			dst = proxy!Dst(src);
		}
		else static if (convToStyle == ConvStyle.type6)
		{
			proxy(src, dst);
		}
		else static assert(0);
	}
	static void convertTo(Dst)(in auto ref Val src, ref Dst dst)
	if (canConvTo!(value, Dst))
	{
		enum convToStyle = getConvToStyle!(value, Dst);
		static if (convToStyle == ConvStyle.type1)
		{
			dst = proxy.to(src);
		}
		else static if (convToStyle == ConvStyle.type2)
		{
			dst = proxy.to!Dst(src);
		}
		else static if (convToStyle == ConvStyle.type3)
		{
			proxy.to(src, dst);
		}
		else static if (convToStyle == ConvStyle.type4)
		{
			dst = proxy(src);
		}
		else static if (convToStyle == ConvStyle.type5)
		{
			dst = proxy!Dst(src);
		}
		else static if (convToStyle == ConvStyle.type6)
		{
			proxy(src, dst);
		}
		else static assert(0);
	}
}

///
public template convertFrom(alias value)
{
	alias proxy = getConvBy!value;
	alias Val   = typeof(value);
	static void convertFrom(Src)(auto ref Src src, ref Val dst)
	if (canConvFrom!(value, Src))
	{
		enum convFromStyle = getConvFromStyle!(value, Src);
		static if (convFromStyle == ConvStyle.type1)
		{
			dst = proxy.from(src);
		}
		else static if (convFromStyle == ConvStyle.type2)
		{
			dst = proxy.from!Val(src);
		}
		else static if (convFromStyle == ConvStyle.type3)
		{
			proxy.from(src, dst);
		}
		else static if (convFromStyle == ConvStyle.type4)
		{
			dst = proxy(src);
		}
		else static if (convFromStyle == ConvStyle.type5)
		{
			dst = proxy!Val(src);
		}
		else static if (convFromStyle == ConvStyle.type6)
		{
			proxy(src, dst);
		}
		else static assert(0);
	}
	static void convertFrom(Src)(in auto ref Src src, ref Val dst)
	if (canConvFrom!(value, Src))
	{
		enum convFromStyle = getConvFromStyle!(value, Src);
		static if (convFromStyle == ConvStyle.type1)
		{
			dst = proxy.from(src);
		}
		else static if (convFromStyle == ConvStyle.type2)
		{
			dst = proxy.from!Val(src);
		}
		else static if (convFromStyle == ConvStyle.type3)
		{
			proxy.from(src, dst);
		}
		else static if (convFromStyle == ConvStyle.type4)
		{
			dst = proxy(src);
		}
		else static if (convFromStyle == ConvStyle.type5)
		{
			dst = proxy!Val(src);
		}
		else static if (convFromStyle == ConvStyle.type6)
		{
			proxy(src, dst);
		}
		else static assert(0);
	}
}


///
enum isConvertible(alias value, T) = canConvTo!(value, T) && canConvFrom!(value, T);


//##############################################################################
//####### from voile.void
//##############################################################################
public:

import std.json, std.traits, std.meta, std.conv, std.array;


/*******************************************************************************
 * Get data from JSONValue
 */
JSONValue json(T)(auto const ref T[] x) @property
if (isSomeString!(T[]))
{
	return JSONValue(to!string(x));
}

/// ditto
JSONValue json(T)(auto const ref T x) @property
if ((isIntegral!T && !is(T == enum))
 || isFloatingPoint!T
 || is(Unqual!T == bool))
{
	return JSONValue(x);
}

/// ditto
JSONValue json(T)(auto const ref T x) @property
if (is(T == enum))
{
	return JSONValue(x.to!string());
}

/// ditto
JSONValue json(T)(auto const ref T[] ary) @property
if (!isSomeString!(T[]) && isArray!(T[]))
{
	auto app = appender!(JSONValue[])();
	JSONValue v;
	foreach (x; ary)
	{
		app.put(x.json);
	}
	v.array = app.data;
	return v;
}

/// ditto
JSONValue json(Value, Key)(auto const ref Value[Key] aa) @property
if (isSomeString!Key && is(typeof({auto v = Value.init.json;})))
{
	auto ret = JSONValue((JSONValue[string]).init);
	static if (is(Key: const string))
	{
		foreach (key, val; aa)
			ret.object[key] = val.json;
	}
	else
	{
		foreach (key, val; aa)
			v.object[key.to!string] = val.json;
	}
	return ret;
}

/// ditto
JSONValue json(JV)(auto const ref JV v) @property
	if (is(JV: const JSONValue))
{
	return cast(JSONValue)v;
}


private void _setValue(T)(ref JSONValue v, ref string name, ref T val)
	if (is(typeof(val.json)))
{
	if (v.type != JSONType.object || !v.object)
	{
		v = [name: val.json];
	}
	else
	{
		auto x = v.object;
		x[name] = val.json;
		v = x;
	}
}


/*******************************************************************************
 * Operation of JSONValue
 */
void setValue(T)(ref JSONValue v, string name, T val) pure nothrow @trusted
{
	try
	{
		assumePure!(_setValue!T)(v, name, val);
	}
	catch (Throwable)
	{
	}
}


///
bool fromJson(T)(in ref JSONValue src, ref T dst)
if (isSomeString!T)
{
	if (src.type == JSONType.string)
	{
		static if (is(T: string))
		{
			dst = src.str;
		}
		else
		{
			dst = to!T(src.str);
		}
		return true;
	}
	return false;
}


/// ditto
bool fromJson(T)(in ref JSONValue src, ref T dst)
	if (isIntegral!T && !is(T == enum))
{
	if (src.type == JSONType.integer)
	{
		dst = cast(T)src.integer;
		return true;
	}
	else if (src.type == JSONType.uinteger)
	{
		dst = cast(T)src.uinteger;
		return true;
	}
	return false;
}

/// ditto
bool fromJson(T)(in ref JSONValue src, ref T dst)
	if (isFloatingPoint!T)
{
	switch (src.type)
	{
	case JSONType.float_:
		dst = cast(T)src.floating;
		return true;
	case JSONType.integer:
		dst = cast(T)src.integer;
		return true;
	case JSONType.uinteger:
		dst = cast(T)src.uinteger;
		return true;
	default:
		return false;
	}
}

/// ditto
bool fromJson(T)(in ref JSONValue src, ref T dst)
if (is(T == struct)
 && !is(Unqual!T: JSONValue))
{
	static if (__traits(compiles, { dst.json = src; }))
	{
		dst.json = src;
	}
	else static foreach (memberIdx, member; T.tupleof)
	{{
		static if (!hasIgnore!member)
		{
			static if (hasName!member)
			{
				enum fieldName = getName!member;
			}
			else
			{
				enum fieldName = __traits(identifier, member);
			}
			static if (hasConvBy!member)
			{
				static if (hasEssential!member)
				{
					dst.tupleof[memberIdx] = convFrom!(member, JSONValue)(src[fieldName]);
				}
				else
				{
					if (auto pJsonValue = fieldName in src)
					{
						try
							dst.tupleof[memberIdx] = convFrom!(member, JSONValue)(*pJsonValue);
						catch (Exception e)
						{
							/* ignore */
						}
					}
				}
			}
			else static if (__traits(compiles, fromJson(src[fieldName], dst.tupleof[memberIdx])))
			{
				static if (hasEssential!member)
				{
					if (!fromJson(src[fieldName], dst.tupleof[memberIdx]))
						return false;
				}
				else
				{
					import std.algorithm: move;
					auto tmp = src.getValue(fieldName, dst.tupleof[memberIdx]);
					move(tmp, dst.tupleof[memberIdx]);
				}
			}
			else
			{
				return false;
			}
		}
	}}
	return true;
}

/// ditto
bool fromJson(T)(in ref JSONValue src, ref T dst)
if (is(T == class))
{
	if (src.type == JSONType.object)
	{
		if (!dst)
			dst = new T;
		dst.json = src;
		return true;
	}
	return false;
}

/// ditto
bool fromJson(T)(in ref JSONValue src, ref T dst)
	if (is(T == enum))
{
	if (src.type == JSONType.string)
	{
		dst = to!T(src.str);
		return true;
	}
	return false;
}

/// ditto
bool fromJson(T)(in ref JSONValue src, ref T dst)
	if (is(T == bool))
{
	if (src.type == JSONType.true_)
	{
		dst = true;
		return true;
	}
	else if (src.type == JSONType.false_)
	{
		dst = false;
		return true;
	}
	return false;
}

/// ditto
bool fromJson(T)(in ref JSONValue src, ref T dst)
	if (!isSomeString!(T) && isDynamicArray!(T))
{
	alias E = ForeachType!T;
	if (src.type == JSONType.array)
	{
		dst = (dst.length >= src.array.length) ? dst[0..src.array.length]: new E[src.array.length];
		foreach (ref i, ref e; src.array)
		{
			if (!fromJson(e, dst[i]))
				return false;
		}
		return true;
	}
	return false;
}

/// ditto
bool fromJson(Value, Key)(in ref JSONValue src, ref Value[Key] dst)
	if (isSomeString!Key && is(typeof({ JSONValue val; cast(void)fromJson(val, dst[Key.init]); })))
{
	if (src.type == JSONType.object)
	{
		foreach (key, ref val; src.object)
		{
			static if (is(Key: const string))
			{
				Value tmp;
				if (!fromJson(val, tmp))
					return false;
				dst[key] = tmp;
			}
			else
			{
				Value tmp;
				if (!fromJson(val, tmp))
					return false;
				dst[to!Key(key)] = tmp;
			}
		}
		return true;
	}
	return false;
}

/// ditto
bool fromJson(T)(in ref JSONValue src, ref T dst)
	if (is(Unqual!T == JSONValue))
{
	dst = src;
	return true;
}


private T _getValue(T)(in ref JSONValue v, string name, lazy scope T defaultVal = T.init)
{
	if (auto x = name in v.object)
	{
		static if (is(T == struct)
		        && !is(Unqual!T: JSONValue)
		        && __traits(compiles, lvalueOf!T.json(rvalueOf!JSONValue)))
		{
			auto ret = T.init;
			ret.json = *x;
			return ret;
		}
		else static if (is(T == class))
		{
			auto ret = new T;
			ret.json = *x;
			return ret;
		}
		else static if (!isSomeString!(T) && isDynamicArray!(T))
		{
			Unqual!(ForeachType!T)[] tmp;
			return fromJson(*x, tmp) ? cast(T)tmp : defaultVal;
		}
		else
		{
			T tmp;
			return fromJson(*x, tmp) ? tmp : defaultVal;
		}
	}
	return defaultVal;
}

///
T getValue(T)(in ref JSONValue v, string name, lazy scope T defaultVal = T.init) nothrow pure @trusted
{
	try
	{
		return assumePure(&_getValue!(Unqual!T))(v, name, defaultVal);
	}
	catch(Throwable)
	{
	}
	try
	{
		return defaultVal;
	}
	catch (Throwable)
	{
	}
	return T.init;
}

///
struct AttrConverter(T)
{
	///
	T function(in JSONValue v) from;
	///
	JSONValue function(in T v) to;
}

/*******************************************************************************
 * Attribute converting method
 */
AttrConverter!T converter(T)(T function(in JSONValue) from, JSONValue function(in T) to)
{
	return AttrConverter!T(from, to);
}


private enum isJSONizableRaw(T) = is(typeof({
	T val;
	JSONValue jv= val.json;
	cast(void)fromJson(jv, val);
}));


/*******************************************************************************
 * serialize data to JSON
 */
JSONValue serializeToJson(T)(in T data)
{
	static if (isJSONizableRaw!T)
	{
		return data.json;
	}
	else static if (is(typeof(_serializeToJsonImpl(data)): JSONValue))
	{
		return _serializeToJsonImpl(data);
	}
	else static if (isArray!T)
	{
		JSONValue[] jvAry;
		auto len = data.length;
		jvAry.length = len;
		foreach (idx; 0..len)
			jvAry[idx] = serializeToJson(data[idx]);
		return JSONValue(jvAry);
	}
	else static if (isAssociativeArray!T)
	{
		JSONValue[string] jvObj;
		foreach (pair; data.byPair)
			jvObj[pair.key.to!string()] = serializeToJson(pair.value);
		return JSONValue(jvObj);
	}
	else
	{
		JSONValue ret;
		static foreach (memberIdx, member; T.tupleof)
		{{
			static if (!hasIgnore!member)
			{
				static if (hasName!member)
				{
					enum fieldName = getName!member;
				}
				else
				{
					enum fieldName = __traits(identifier, member);
				}
				static if (hasConvBy!member)
				{
					ret[fieldName] = convTo!(member, JSONValue)(data.tupleof[memberIdx]);
				}
				else static if (isJSONizableRaw!(typeof(member)))
				{
					ret[fieldName] = data.tupleof[memberIdx].json;
				}
				else
				{
					ret[fieldName] = serializeToJson(data.tupleof[memberIdx]);
				}
			}
		}}
		return ret;
	}
}

/// ditto
string serializeToJsonString(T)(in T data, JSONOptions options = JSONOptions.none)
{
	return serializeToJson(data).toPrettyString(options);
}


/*******************************************************************************
 * deserialize data from JSON
 */
void deserializeFromJson(T)(ref T data, in JSONValue json)
{
	static if (isJSONizableRaw!T)
	{
		cast(void)fromJson(json, data);
	}
	else static if (__traits(compiles, _deserializeFromJsonImpl(data, json)))
	{
		_deserializeFromJsonImpl(data, json);
	}
	else static if (isArray!T)
	{
		if (json.type != JSONType.array)
			return;
		auto jvAry = json.array;
		static if (isDynamicArray!T)
			data.length = jvAry.length;
		foreach (idx, ref dataElm; data)
			deserializeFromJson(dataElm, jvAry[idx]);
	}
	else static if (isAssociativeArray!T)
	{
		if (json.type != JSONType.object)
			return;
		data.clear();
		alias KeyType = typeof(data.byKey.front);
		alias ValueType = typeof(data.byValue.front);
		foreach (pair; json.object.byPair)
		{
			import std.algorithm: move;
			data.update(pair.key.to!KeyType(),
			{
				ValueType ret;
				deserializeFromJson(ret, pair.value);
				return ret.move();
			}, (ref ValueType ret)
			{
				deserializeFromJson(ret, pair.value);
				return ret;
			});
		}
	}
	else
	{
		static foreach (memberIdx, member; T.tupleof)
		{{
			static if (!hasIgnore!member)
			{
				static if (hasName!member)
				{
					enum fieldName = getName!member;
				}
				else
				{
					enum fieldName = __traits(identifier, member);
				}
				static if (hasConvBy!member)
				{
					static if (hasEssential!member)
					{
						data.tupleof[memberIdx] = convFrom!(member, JSONValue)(json[fieldName]);
					}
					else
					{
						if (auto pJsonValue = fieldName in json)
						{
							try
								data.tupleof[memberIdx] = convFrom!(member, JSONValue)(*pJsonValue);
							catch (Exception e)
							{
								/* ignore */
							}
						}
						
					}
				}
				else static if (isJSONizableRaw!(typeof(member)))
				{
					static if (hasEssential!member)
					{
						cast(void)fromJson(json[fieldName], data.tupleof[memberIdx]);
					}
					else
					{
						import std.algorithm: move;
						auto tmp = json.getValue(fieldName, data.tupleof[memberIdx]);
						move(tmp, data.tupleof[memberIdx]);
					}
				}
				else
				{
					static if (hasEssential!member)
					{
						deserializeFromJson(data.tupleof[memberIdx], json[fieldName]);
					}
					else
					{
						if (auto pJsonValue = fieldName in json)
							deserializeFromJson(data.tupleof[memberIdx], *pJsonValue);
					}
				}
			}
		}}
	}
}

/// ditto
void deserializeFromJsonString(T)(ref T data, string jsonContents)
{
	deserializeFromJson(data, parseJSON(jsonContents));
}

@system unittest
{
	enum EnumVal
	{
		val1,
		val2
	}
	struct Data
	{
		EnumVal val;
	}
	Data data1 = Data(EnumVal.val1), data2 = Data(EnumVal.val2);
	auto jv = data1.serializeToJson();
	data2.deserializeFromJson(jv);
	assert(data1.val == data2.val);
}


@system unittest
{
	struct Data
	{
		string[uint] map;
	}
	Data data1 = Data([1: "1"]);
	Data data2 = Data([2: "2"]);
	auto jv = data1.serializeToJson();
	data2.deserializeFromJson(jv);
	assert(1 in data1.map);
	assert(1 in data2.map);
	assert(2 !in data2.map);
	assert(data2.map[1] == "1");
}

