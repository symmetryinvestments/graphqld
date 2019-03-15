module schema.types;

import std.conv : to;
import std.array;
import std.meta;
import std.traits;
import std.typecons;
import std.algorithm : map, joiner, canFind;
import std.range : ElementEncodingType;
import std.format;
import std.string : strip;
import std.experimental.logger;

import vibe.data.json;

import helper;
import traits;

@safe:

enum GQLDKind {
	String,
	Float,
	Int,
	Bool,
	Object_,
	List,
	Enum,
	Map,
	Nullable,
	NonNull,
	Union,
	Query,
	Mutation,
	Subscription,
	Schema
}

abstract class GQLDType {

	const GQLDKind kind;
	string name;

	this(GQLDKind kind) {
		this.kind = kind;
	}

	override string toString() const {
		return "GQLDType";
	}

	string toShortString() const {
		return this.toString();
	}
}

class GQLDScalar : GQLDType {
	this(GQLDKind kind) {
		super(kind);
	}
}

class GQLDString : GQLDScalar {
	this() {
		super(GQLDKind.String);
		super.name = "String";
	}

	override string toString() const {
		return "String";
	}
}

class GQLDFloat : GQLDScalar {
	this() {
		super(GQLDKind.Float);
		super.name = "Float";
	}

	override string toString() const {
		return "Float";
	}
}

class GQLDInt : GQLDScalar {
	this() {
		super(GQLDKind.Int);
		super.name = "Int";
	}

	override string toString() const {
		return "Int";
	}
}

class GQLDEnum : GQLDScalar {
	string enumName;
	this(string enumName) {
		super(GQLDKind.Enum);
		this.enumName = enumName;
		super.name = enumName;
	}

	override string toString() const {
		return this.enumName;
	}
}

class GQLDBool : GQLDScalar {
	this() {
		super(GQLDKind.Bool);
		super.name = "Bool";
	}

	override string toString() const {
		return "Bool";
	}
}

class GQLDMap : GQLDType {
	GQLDType[string] member;
	GQLDMap[] derivatives;

	this() {
		super(GQLDKind.Map);
	}
	this(GQLDKind kind) {
		super(kind);
	}

	void addDerivative(GQLDMap d) {
		if(!canFind!((a,b) => a is b)(this.derivatives, d)) {
			this.derivatives ~= d;
		}
	}

	override string toString() const {
		auto app = appender!string();
		foreach(key, value; this.member) {
			formattedWrite(app, "%s: %s\n", key, value.toString());
		}
		return app.data;
	}
}

class GQLDObject : GQLDMap {
	GQLDObject _base;

	@property const(GQLDObject) base() const {
		return cast(const)this._base;
	}

	@property void base(GQLDObject nb) {
		this._base = nb;
	}

	this(string name) {
		super(GQLDKind.Object_);
		super.name = name;
	}

	override string toString() const {
		return format(
				"Object %s(%s))\n\t\t\t\tBase(%s)\n\t\t\t\tDerivaties(%s)",
				this.name,
				this.member
					.byKeyValue
					.map!(kv => format("%s %s", kv.key,
							kv.value.toShortString()))
					.joiner(",\n\t\t\t\t"),
				(this.base !is null ? this.base.toShortString() : "null"),
				this.derivatives.map!(d => d.toShortString())
			);
	}

	override string toShortString() const {
		return format("%s", super.name);
	}
}

class GQLDUnion : GQLDMap {
	this(string name) {
		super(GQLDKind.Union);
		super.name = name;
	}

	override string toString() const {
		return format("Union %s(%s))\n\t\t\t\tDerivaties(%s)",
				this.name,
				this.member
					.byKeyValue
					.map!(kv => format("%s %s", kv.key,
							kv.value.toShortString()))
					.joiner(",\n\t\t\t\t"),
				this.derivatives.map!(d => d.toShortString())
			);
	}
}

class GQLDList : GQLDType {
	GQLDType elementType;

	this(GQLDType elemType) {
		super(GQLDKind.List);
		super.name = "List";
		this.elementType = elemType;
	}

	override string toString() const {
		return format("List(%s)", this.elementType.toShortString());
	}

	override string toShortString() const {
		return format("List(%s)", this.elementType.toShortString());
	}
}

class GQLDNonNull : GQLDType {
	GQLDType elementType;

	this(GQLDType elemType) {
		super(GQLDKind.NonNull);
		super.name = "NonNull";
		this.elementType = elemType;
	}

	override string toString() const {
		return format("NonNull(%s)", this.elementType.toShortString());
	}

	override string toShortString() const {
		return format("NonNull(%s)", this.elementType.toShortString());
	}
}

class GQLDNullable : GQLDType {
	GQLDType elementType;

	this(GQLDType elemType) {
		super(GQLDKind.Nullable);
		super.name = "Nullable";
		this.elementType = elemType;
	}

	override string toString() const {
		return format("Nullable(%s)", this.elementType.toShortString());
	}

	override string toShortString() const {
		return format("Nullable(%s)", this.elementType.toShortString());
	}
}

class GQLDOperation : GQLDType {
	GQLDType returnType;
	string returnTypeName;

	GQLDType[string] parameters;

	this(GQLDKind kind) {
		super(kind);
	}

	override string toString() const {
		return format("%s %s(%s)", super.kind, returnType.toShortString(),
				this.parameters
					.byKeyValue
					.map!(kv =>
						format("%s %s", kv.key, kv.value.toShortString())
					)
					.joiner(", ")
				);
	}
}

class GQLDQuery : GQLDOperation {
	this() {
		super(GQLDKind.Query);
		super.name = "Query";
	}
}

class GQLDMutation : GQLDOperation {
	this() {
		super(GQLDKind.Mutation);
		super.name = "Mutation";
	}
}

class GQLDSubscription : GQLDOperation {
	this() {
		super(GQLDKind.Subscription);
		super.name = "Subscription";
	}
}

class GQLDSchema(Type) : GQLDMap {
	GQLDType[string] types;

	GQLDObject __schema;
	GQLDObject __type;
	GQLDObject __field;
	GQLDObject __inputValue;
	GQLDObject __enumValue;
	GQLDObject __directives;

	GQLDNonNull __nonNullType;
	GQLDNullable __nullableType;
	GQLDNullable __listOfNonNullType;
	GQLDNonNull __nonNullListOfNonNullType;
	GQLDNonNull __nonNullField;
	GQLDNullable __listOfNonNullField;
	GQLDNonNull __nonNullInputValue;
	GQLDList __listOfNonNullInputValue;
	GQLDNonNull __nonNullListOfNonNullInputValue;
	GQLDList __listOfNonNullEnumValue;

	this() {
		super(GQLDKind.Schema);
		super.name = "Schema";
		this.createInbuildTypes();
		this.createIntrospectionTypes();
	}

	void createInbuildTypes() {
		this.types["string"] = new GQLDString();
		foreach(t; ["String", "Int", "Float", "Bool"]) {
			GQLDObject tmp = new GQLDObject(t);
			this.types[t] = tmp;
			tmp.member["name"] = new GQLDString();
			tmp.member["description"] = new GQLDString();
			tmp.member["kind"] = new GQLDEnum("__TypeKind");
			//tmp.resolver = buildTypeResolver!(Type,Con)();
		}
	}

	void createIntrospectionTypes() {
		// build base types
		auto str = new GQLDString();
		auto nnStr = new GQLDNonNull(str);
		auto nllStr = new GQLDNullable(str);

		auto b = new GQLDBool();
		auto nnB = new GQLDNonNull(b);
		this.__schema = new GQLDObject("__schema");
		this.__type = new GQLDObject("__Type");
		this.__schema.member["mutationType"] = this.__type;
		this.__schema.member["subscriptionType"] = this.__type;

		this.__nullableType = new GQLDNullable(this.__type);
		this.__type.member["ofType"] = this.__nullableType;
		this.__type.member["kind"] = new GQLDEnum("__TypeKind");
		this.__type.member["name"] = nllStr;
		this.__type.member["description"] = nllStr;

		this.__nonNullType = new GQLDNonNull(this.__type);
		this.__schema.member["queryType"] = this.__nonNullType;
		auto lNNTypes = new GQLDList(this.__nonNullType);
		auto nlNNTypes = new GQLDNullable(lNNTypes);
		this.__listOfNonNullType = new GQLDNullable(lNNTypes);
		this.__type.member["interfaces"] = nlNNTypes;
		this.__type.member["possibleTypes"] = nlNNTypes;

		this.__nonNullListOfNonNullType = new GQLDNonNull(lNNTypes);
		this.__schema.member["types"] = this.__nonNullListOfNonNullType;

		this.__field = new GQLDObject("__Field");
		this.__field.member["name"] = nnStr;
		this.__field.member["description"] = nllStr;
		this.__field.member["type"] = this.__nonNullType;
		this.__field.member["isDeprecated"] = nnB;
		this.__field.member["deprecationReason"] = nllStr;

		this.__nonNullField = new GQLDNonNull(this.__field);
		auto lNNFields = new GQLDList(this.__nonNullField);
		this.__listOfNonNullField = new GQLDNullable(lNNFields);
		this.__type.member["fields"] = this.__listOfNonNullField;

		this.__inputValue = new GQLDObject("__InputValue");
		this.__inputValue.member["name"] = nnStr;
		this.__inputValue.member["description"] = nllStr;
		this.__inputValue.member["defaultValue"] = nllStr;
		this.__inputValue.member["type"] = this.__nonNullType;

		this.__nonNullInputValue = new GQLDNonNull(this.__inputValue);
		this.__listOfNonNullInputValue = new GQLDList(
				this.__nonNullInputValue
			);
		auto nlNNInputValue = new GQLDNullable(
				this.__listOfNonNullInputValue
			);

		this.__type.member["inputFields"] = nlNNInputValue;

		this.__nonNullListOfNonNullInputValue = new GQLDNonNull(
				this.__listOfNonNullInputValue
			);

		this.__field.member["args"] = this.__nonNullListOfNonNullInputValue;

		this.__enumValue = new GQLDObject("__EnumValue");
		this.__enumValue.member["name"] = nnStr;
		this.__enumValue.member["description"] = nllStr;
		this.__enumValue.member["isDeprecated"] = nnB;
		this.__enumValue.member["deprecationReason"] = nllStr;

		this.__listOfNonNullEnumValue = new GQLDList(new GQLDNonNull(
				this.__enumValue
			));

		this.__type.member["enumValues"] = this.__listOfNonNullEnumValue;

		this.__directives = new GQLDObject("__Directive");
		this.__directives.member["name"] = nnStr;
		this.__directives.member["description"] = str;
		this.__directives.member["args"] =
			this.__nonNullListOfNonNullInputValue;
		this.__directives.member["locations"] = new GQLDNonNull(
				this.__listOfNonNullEnumValue
			);

		this.__schema.member["directives"] = new GQLDNonNull(
				new GQLDList(new GQLDNonNull(this.__directives))
			);


		foreach(t; ["String", "Int", "Float", "Bool"]) {
			this.types[t].toObject().member["fields"] =
				this.__listOfNonNullField;
		}
	}

	override string toString() const {
		auto app = appender!string();
		formattedWrite(app, "Operation\n");
		foreach(key, value; super.member) {
			formattedWrite(app, "%s: %s\n", key, value.toString());
		}

		formattedWrite(app, "Types\n");
		foreach(key, value; this.types) {
			formattedWrite(app, "%s: %s\n", key, value.toString());
		}
		return app.data;
	}

	GQLDType getReturnType(GQLDType t, string field) {
		logf("'%s' '%s'", t.name, field);
		GQLDType ret;
		if(auto s = t.toScalar()) {
			//log();
			ret = s;
		} else if(auto op = t.toOperation()) {
			//log();
			ret = op.returnType;
		} else if(auto map = t.toMap()) {
			if((map.name == "query" || map.name == "mutation"
						|| map.name == "subscription")
					&& field in map.member)
			{
				log();
				auto tmp = map.member[field];
				if(auto op = tmp.toOperation()) {
					//log();
					ret = op.returnType;
				} else {
					log();
					ret = tmp;
				}
			} else if(field in map.member) {
				log();
				ret = map.member[field];
			} else if(field == "__typename") {
				ret = this.types["string"];
			} else {
				// if we couldn't find it in the passed map, maybe it is in some
				// of its derivatives
				foreach(deriv; map.derivatives) {
					if(field in deriv.member) {
						return deriv.member[field];
					}
				}
				return null;
			}
		} else {
			ret = t;
		}
		logf("%s", ret.name);
		return ret;
	}
}

GQLDObject toObject(GQLDType t) {
	return cast(typeof(return))t;
}

GQLDMap toMap(GQLDType t) {
	return cast(typeof(return))t;
}

GQLDScalar toScalar(GQLDType t) {
	return cast(typeof(return))t;
}

GQLDOperation toOperation(GQLDType t) {
	return cast(typeof(return))t;
}

GQLDList toList(GQLDType t) {
	return cast(typeof(return))t;
}

GQLDNullable toNullable(GQLDType t) {
	return cast(typeof(return))t;
}

GQLDNonNull toNonNull(GQLDType t) {
	return cast(typeof(return))t;
}

unittest {
	auto str = new GQLDString();
	assert(str.name == "String");

	auto map = str.toMap();
	assert(map is null);
}

string toShortString(const(GQLDType) e) {
	if(auto o = cast(const(GQLDObject))e) {
		return o.name;
	} else if(auto u = cast(const(GQLDUnion))e) {
		return u.name;
	} else {
		return e.toString();
	}
}

GQLDType typeToGQLDType(Type, SCH)(ref SCH ret) {
	pragma(msg, Type.stringof, " ", isIntegral!Type);
	static if(is(Type == enum)) {
		GQLDEnum r;
		if(Type.stringof in ret.types) {
			r = cast(GQLDEnum)ret.types[Type.stringof];
		} else {
			r = new GQLDEnum(Type.stringof);
			ret.types[Type.stringof] = r;
		}
		return r;
	} else static if(is(Type == bool)) {
		return new GQLDBool();
	} else static if(isFloatingPoint!(Type)) {
		return new GQLDFloat();
	} else static if(isIntegral!(Type)) {
		return new GQLDInt();
	} else static if(isSomeString!Type) {
		return new GQLDString();
	} else static if(is(Type == union)) {
		GQLDUnion r;
		if(Type.stringof in ret.types) {
			r = cast(GQLDUnion)ret.types[Type.stringof];
		} else {
			r = new GQLDUnion(Type.stringof);
			ret.types[Type.stringof] = r;

			alias fieldNames = FieldNameTuple!(Type);
			alias fieldTypes = Fields!(Type);
			static foreach(idx; 0 .. fieldNames.length) {{
				auto tmp = typeToGQLDType!(fieldTypes[idx])(ret);
				r.member[fieldNames[idx]] = tmp;

				if(GQLDMap tmpMap = tmp.toMap()) {
					r.addDerivative(tmpMap);
				}
			}}
		}
		return r;
	} else static if(is(Type : Nullable!F, F)) {
		return new GQLDNullable(typeToGQLDType!(F)(ret));
	} else static if(isArray!Type) {
		return new GQLDList(typeToGQLDType!(ElementEncodingType!Type)(ret)
			);
	} else static if(isAggregateType!Type) {
		GQLDObject r;
		if(Type.stringof in ret.types) {
			r = cast(GQLDObject)ret.types[Type.stringof];
		} else {
			r = new GQLDObject(Type.stringof);
			ret.types[Type.stringof] = r;

			alias fieldNames = FieldNameTuple!(Type);
			alias fieldTypes = Fields!(Type);
			static foreach(idx; 0 .. fieldNames.length) {{
				r.member[fieldNames[idx]] =
					typeToGQLDType!(fieldTypes[idx])(ret);
			}}

			static if(is(Type == class)) {
				alias bct = BaseClassesTuple!(Type);
				static if(bct.length > 1) {
					auto d = cast(GQLDObject)typeToGQLDType!(bct[0])(
							ret
						);
					r.base = d;
					d.addDerivative(r);

				}
				assert(bct.length > 1 ? r.base !is null : true);
			}
		}
		return r;
	} else {
		pragma(msg, "218 ", Type.stringof);
		static assert(false, Type.stringof);
	}
}