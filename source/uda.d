module uda;

import std.traits : isBuiltinType;

enum TypeKind {
	UNDEFINED,
	SCALAR,
	OBJECT,
	INTERFACE,
	UNION,
	ENUM,
	INPUT_OBJECT,
	LIST,
	NON_NULL
}

struct GQLDUdaData {
	TypeKind typeKind;
	GQLDDeprecatedData deprecationInfo;
	GQLDDescription description;
}

enum IsDeprecated {
	undefined,
	yes,
	no
}

struct GQLDDeprecatedData {
	IsDeprecated isDeprecated;
	string deprecationReason;
}

struct GQLDDescription {
	string text;
}

GQLDDeprecatedData GQLDDeprecated(IsDeprecated isDeprecated) {
	return GQLDDeprecatedData(isDeprecated, "");
}

GQLDDeprecatedData GQLDDeprecated(IsDeprecated isDeprecated,
		string deprecationReason)
{
	return GQLDDeprecatedData(isDeprecated, deprecationReason);
}

GQLDUdaData GQLDUda(Args...)(Args args) {
	GQLDUdaData ret;
	static foreach(mem; __traits(allMembers, GQLDUdaData)) {
		static foreach(arg; args) {
			static if(is(typeof(__traits(getMember, ret, mem)) ==
						typeof(arg)))
			{
				__traits(getMember, ret, mem) = arg;
			}
		}
	}
	return ret;
}

template isGQLDUdaData(alias Type) {
	enum isGQLDUdaData = is(typeof(Type) == GQLDUdaData);
}

template getGQLDUdaData(Type, string mem) {
	import std.meta : Filter;
	alias getGQLDUdaData =
		Filter!(isGQLDUdaData,
				__traits(getAttributes, __traits(getMember, Type, mem)));
}

template getGQLDUdaData(Type) {
	import std.meta : Filter;
	alias getGQLDUdaData =
		Filter!(isGQLDUdaData, __traits(getAttributes, Type));
}

template getUdaData(Type) {
	static if(isBuiltinType!Type) {
		enum getUdaData = GQLDUdaData.init;
	} else {
		alias GQLDUdaDataAS = getGQLDUdaData!Type;
		static if(GQLDUdaDataAS.length > 0) {
			enum getUdaData = GQLDUdaDataAS[0];
		} else {
			enum getUdaData = GQLDUdaData.init;
		}
	}
}

template getUdaData(Type, string mem) {
	//static if(isBuiltinType!(typeof(__traits(getMember, Type, mem)))) {
	//	enum  getUdaData = GQLDUdaData.init;
	//} else {
		alias GQLDUdaDataAS = getGQLDUdaData!(Type, mem);
		static if(GQLDUdaDataAS.length > 0) {
			enum  getUdaData = GQLDUdaDataAS[0];
		} else {
			enum  getUdaData = GQLDUdaData.init;
		}
	//}
}

unittest {
	@GQLDUda(
		GQLDDeprecated(IsDeprecated.yes, "Stupid name"),
		GQLDDescription("You normal test struct")
	)
	struct Foo {
		@GQLDUda(
			GQLDDeprecated(IsDeprecated.no, "Very good name"),
			GQLDDescription("Contains something")
		)
		int bar;

		int args;
	}

	enum GQLDUdaData fd = getUdaData!Foo;
	static assert(fd.deprecationInfo.isDeprecated == IsDeprecated.yes);
	static assert(fd.deprecationInfo.deprecationReason == "Stupid name");
	static assert(fd.description.text == "You normal test struct");

	enum GQLDUdaData bd = getUdaData!(Foo, "bar");
	static assert(bd.deprecationInfo.isDeprecated == IsDeprecated.no);
	static assert(bd.deprecationInfo.deprecationReason == "Very good name");
	static assert(bd.description.text == "Contains something");

	enum GQLDUdaData ad = getUdaData!(Foo, "args");
	static assert(ad.deprecationInfo.isDeprecated == IsDeprecated.undefined);
	static assert(ad.deprecationInfo.deprecationReason == "");
	static assert(ad.description.text == "");
}