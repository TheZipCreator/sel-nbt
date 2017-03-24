﻿/*
 * Copyright (c) 2017
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 * 
 */
module nbt.tags;

import std.algorithm : canFind;
import std.conv : to;
import std.json : JSONValue;
import std.string : capitalize;
import std.traits : isAbstractClass, isNumeric;
import std.typetuple : TypeTuple;

import nbt.stream;

/**
 * NBT's ids, as unsigned bytes, used by for client-server
 * and generic io communication.
 */
enum NBT_TYPE : ubyte {
	
	END = 0,
	BYTE = 1,
	SHORT = 2,
	INT = 3,
	LONG = 4,
	FLOAT = 5,
	DOUBLE = 6,
	BYTE_ARRAY = 7,
	STRING = 8,
	LIST = 9,
	COMPOUND = 10,
	INT_ARRAY = 11
	
}

alias Tags = TypeTuple!(null, Byte, Short, Int, Long, Float, Double, ByteArray, String, List, Compound, IntArray);

/**
 * Base class for every NBT that contains id and encoding
 * functions (the endianness may vary from a Minecraft version
 * to another and the purpose of the tags in the game).
 */
interface Tag {

	/**
	 * Gets the tag's type.
	 */
	public pure nothrow @property @safe @nogc NBT_TYPE type();

	/**
	 * Creates a NamedTag maintaing the tag's properties.
	 * Example:
	 * ---
	 * auto t = new Float(22);
	 * auto named = t.rename("float");
	 * assert(cast(NamedTag)named);
	 * assert(named.name == "float");
	 * assert(named == 22);
	 * ---
	 */
	public pure nothrow @safe NamedTag rename(string name);

	/**
	 * Encodes the tag's body.
	 */
	public pure nothrow @safe void encode(Stream stream);

	/**
	 * Decodes the tag's body.
	 */
	public pure nothrow @safe void decode(Stream stream);
	
	/**
	 * Encodes the tag's value as json.
	 */
	public JSONValue toJSON();

	public string toString();
	
}

interface NamedTag : Tag {

	public pure nothrow @property @safe @nogc string name();

}

template Named(T:Tag) if(is(T == class) && !isAbstractClass!T && !is(T : NamedTag)) {

	class Named : T, NamedTag {

		private string n_name;

		public this(E...)(string name, E args) {
			super(args);
			this.n_name = name;
		}

		public final override pure nothrow @property @safe @nogc string name() {
			return this.n_name;
		}

		public override bool opEquals(Object o) {
			auto cmp = cast(typeof(this))o;
			return cmp !is null && this.name == cmp.name && super.opEquals(o);
		}

		public bool opEquals(T)(T o) if(!is(T : Object)) {
			return super.opEquals(o);
		}

	}

}

/**
 * Simple tag with a value of type T, if T is a primitive type
 * or it can be written in the buffer.
 * Example:
 * ---
 * assert(new Short(1) == 1);
 * assert(new Int("name", 100) == new Byte(100));
 * assert(new SimpleTag!(char, 12)('c') == 'c');
 * ---
 */
class SimpleTag(T, NBT_TYPE _type) : Tag {
	
	public T value;

	public pure nothrow @safe @nogc this(T value=T.init) {
		this.value = value;
	}

	public override pure nothrow @property @safe @nogc NBT_TYPE type() {
		return _type;
	}

	public override pure nothrow @safe NamedTag rename(string name) {
		return new Named!(SimpleTag!(T, _type))(name, this.value);
	}

	public override pure nothrow @safe void encode(Stream stream) {
		mixin("stream.write" ~ capitalize(T.stringof) ~ "(this.value);");
	}

	public override pure nothrow @safe void decode(Stream stream) {
		mixin("this.value = stream.read" ~ capitalize(T.stringof) ~ "();");
	}
	
	public override bool opEquals(Object o) {
		auto c = cast(typeof(this))o;
		return c !is null && this.opEquals(c.value);
	}
	
	public bool opEquals(T value) {
		return this.value == value;
	}

	public override int opCmp(Object o) {
		auto c = cast(typeof(this))o;
		return c !is null && this.opCmp(c.value);
	}

	public int opCmp(T value) {
		return this.value == value ? 0 : (this.value < value ? -1 : 1);
	}

	public override JSONValue toJSON() {
		return JSONValue(this.value);
	}

	public override string toString() {
		return capitalize(T.stringof) ~ "(" ~ to!string(this.value) ~ ")";
	}
	
	alias value this;
	
}

/**
 * Tag with a signed byte, usually used to store small
 * values like the progress of an action or the type of
 * an entity.
 * An unsigned version of the tag can be obtained doing a
 * cast to ubyte.
 * <a href="#ByteArray">Byte Array</a> is a tag with an array
 * of unsigned bytes.
 * Example:
 * ---
 * assert(cast(ubyte)(new Byte(-1)) == 255);
 * ---
 */
alias Byte = SimpleTag!(byte, NBT_TYPE.BYTE);

/**
 * Byte tag that only uses the values 1 and 0 to indicate
 * respectively true and false.
 * It's usually used by SEL to store boolean values instead
 * of a byte tag.
 * Example:
 * ---
 * assert(new Byte(1) == new Bool(true));
 * ---
 */
alias Bool = Byte;

/**
 * Tag with a signed short, used when the 255 bytes (or 127
 * if only the positive part is counted) is not enough.
 * This tag can also be converted to its unsigned version
 * doing a simple cast to ushort.
 */
alias Short = SimpleTag!(short, NBT_TYPE.SHORT);

/**
 * Tag with a signed integer, used to store values that
 * don't usually fit in the short tag, like entity's ids.
 * This tag can aslo be converted to its unsigned version
 * (uint) with a simple cast to it.
 * <a href="#IntArray">Int Array</a> is a tag with an array
 * of signed integers.
 */
alias Int = SimpleTag!(int, NBT_TYPE.INT);

/**
 * Tag with a signed long.
 */
alias Long = SimpleTag!(long, NBT_TYPE.LONG);

/**
 * Tag with a 4-bytes floating point value, usually used to
 * store non-blocks coordinates or points in the world.
 * The float.nan value can be used and recognized by the
 * SEL-derived systems, but couldn't be recognized by other
 * softwares based on different programming languages that
 * doesn't support the not-a-number value.
 * More informations about the NaN value and its encoding
 * can be found on <a href="#https://en.wikipedia.org/wiki/NaN">Wikipedia</a>.
 */
alias Float = SimpleTag!(float, NBT_TYPE.FLOAT);

/**
 * Tag with an 8-bytes float point value used instead of the
 * Float tag if the precision or the available number's range
 * must be higher.
 * See <a href="#Float">Float</a>'s documentation for informations
 * about the NaN value and its support inside and outside SEL.
 */
alias Double = SimpleTag!(double, NBT_TYPE.DOUBLE);

/**
 * Tag with an UTF-8 string encoded as its length as short and
 * its content casted to btyes.
 * Example:
 * ---
 * assert(new String("test") == "");
 * assert(new String("", "test") == "test");
 * ---
 */
alias String = SimpleTag!(string, NBT_TYPE.STRING);

unittest {
	
	assert(new Byte(1) == new Bool(true));
	assert(new Named!Int("test", 12) == new Named!Int("test", 12));
	assert(new Named!Long("test", 44) == 44);
	assert(new Named!Double("test", 0) != new Named!Double("test!", 0));
	assert(new Named!Float("test", 0) != 1);
	assert(12f == new Float(12f));

	auto t = new Int(22);
	t += 44;
	assert(t == 66);
	assert(t > 22);
	t /= 2;
	assert(t == 33);
	assert(t <= 33);
	t = 100;
	assert(t == 100);

	assert(new Long(44).toString() == "Long(44)"); // format may change

	import std.system : Endian;
	Stream stream = new EndianStream!(Endian.bigEndian)();

	new Byte(1).encode(stream);
	new Short(5).encode(stream);
	new Bool(false).encode(stream);
	assert(stream.buffer == [1, 0, 5, 0]);

	auto i = new Int();
	i.decode(stream);
	assert(i == 16778496);
	
}

/**
 * Simple tag with array-related functions.
 * Example:
 * ---
 * assert(new ByteArray([2, 3, 4]).length == new IntArray([9, 0, 12]).length);
 * 
 * auto b = new ByteArray("test");
 * assert(b.empty);
 * b ~= 14;
 * assert(b.length == 1 && b[0] == 14);
 * ---
 */
class ArrayTag(T, NBT_TYPE _type) : Tag {

	public T[] value;

	public pure nothrow @safe @nogc this(T[] value...) {
		this.value = value;
	}

	public override pure nothrow @property @safe @nogc NBT_TYPE type() {
		return _type;
	}

	public override pure nothrow @safe NamedTag rename(string name) {
		return new Named!(ArrayTag!(T, _type))(name, this.value);
	}
	
	/**
	 * Gets the value at the given index.
	 * Returns: the value of type T at the given index
	 * Throws: RangeError if index is higher or equals than the array's length
	 * Example:
	 * ---
	 * assert(new IntArray([1, 14, 900])[1] == 14);
	 * ---
	 */
	public @safe T opIndex(size_t index) {
		return this.value[index];
	}
	
	/**
	 * Sets the value at the given index.
	 * Throws: RangeError if index is higher or equals than the array's length
	 * Example:
	 * ---
	 * auto array = new IntArray([1, 14, 900]);
	 * array[1] = 1;
	 * assert(array == [1, 1, 900]);
	 * ---
	 */
	public @safe void opIndexAssign(T value, size_t index) {
		this.value[index] = value;
	}
	
	/**
	 * Checks if the array contains value.
	 * Returns: true if one the value in the array is equals to value, false otherwise
	 * ---
	 * auto array = new ByteArray(1, 2, 3, 4, 5);
	 * assert(array.contains(1));
	 * assert(!array.contains(0));
	 * assert(array.contains(new Byte("test", 3)));
	 * ---
	 */
	public @trusted bool contains(T value) {
		foreach(T v ; this.value) {
			if(v == value) return true;
		}
		return false;
	}
	
	/**
	 * Concatenates T, an array of T or a NBT array of T to the tag.
	 * Example:
	 * ---
	 * auto array = new IntArray([1]);
	 * 
	 * array ~= 1;
	 * assert(array == [1, 1]);
	 * 
	 * array ~= [1, 2, 3];
	 * assert(array == [1, 1, 1, 2, 3]);
	 *
	 * array ~= new IntArray([100, 99]);
	 * assert(array == [1, 1, 1, 2, 3, 100, 99]);
	 * ---
	 */
	public @safe void opOpAssign(string op : "~", G)(G value) if(is(G == T) || is(G == T[])) {
		this.value ~= value;
	}
	
	/**
	 * Does the same job opOpAssign does, but creates a new instance
	 * of typeof(this) with the same name of the tag and returns it.
	 * Example:
	 * ---
	 * auto array = new IntArray([1, 2, 3]);
	 * assert(array ~ [2, 1] == [1, 2, 3, 2, 1] && array == [1, 2, 3]);
	 * ---
	 */
	public @safe typeof(this) opBinary(string op : "~", G)(G value) if(is(G == T) || is(G == T[])) {
		return new typeof(this)(this.name, this.value ~ value);
	}
	
	/**
	 * Removes the element at the given index from the array.
	 * Throws: RangeError if index is higher or equals than the array's length
	 * Example:
	 * ---
	 * auto array = new IntArray([1, 2, 3]);
	 * array.remove(0);
	 * assert(array == [2, 3]);
	 * ---
	 */
	public @safe void remove(size_t index) {
		this.value = this.value[0..index] ~ this.value[index+1..$];
	}
	
	/**
	 * Checks whether or not the array's length is equals to 0.
	 */
	public final pure nothrow @property @safe @nogc bool empty() {
		return this.length == 0;
	}

	public override pure nothrow @safe void encode(Stream stream) {
		stream.writeLength(this.value.length);
		foreach(v ; this.value) {
			mixin("stream.write" ~ capitalize(T.stringof) ~ "(v);");
		}
	}

	public override pure nothrow @safe void decode(Stream stream) {
		this.value.length = stream.readLength();
		foreach(ref v ; this.value) {
			mixin("v = stream.read" ~ capitalize(T.stringof) ~ "();");
		}
	}

	public override JSONValue toJSON() {
		return JSONValue(this.value);
	}

	public override string toString() {
		return capitalize(T.stringof) ~ "Array(" ~ to!string(this.value) ~ ")";
	}
	
	alias value this;
	
}

/**
 * Array of unsigned bytes (clients and other softwares may
 * interpret the bytes as signed due to limitations of the
 * programming language).
 * The tag is usually used by Minecraft's worlds to store
 * blocks' ids and metas.
 * 
 * If a signed byte is needed a cast operation can be done.
 * Example:
 * ---
 * auto unsigned = new ByteArray([0, 1, 255]);
 * auto signed = cast(byte[])unsigned;
 * assert(signed == [0, 1, -1]);
 * ---
 */
alias ByteArray = ArrayTag!(byte, NBT_TYPE.BYTE_ARRAY);

/**
 * $(TAGS)
 * 
 * Array of signed integers, introduced in the last version
 * of the NBT format. Used by anvil worlds.
 * 
 * The same cast rules also apply for this tag's values.
 * Example:
 * ---
 * auto signed = new IntArray([-1]);
 * assert(cast(uint[])signed == [uint.max]);
 * ---
 */
alias IntArray = ArrayTag!(int, NBT_TYPE.INT_ARRAY);

interface IList {
	
	public pure nothrow @property @safe @nogc ubyte childType();
	
	public @property @safe Tag[] tags();
	
}

class ListImpl(T:Tag) : Tag, IList {

	public T[] value;

	public pure nothrow @safe @nogc this(T[] value) {
		this.value = value;
	}

	public override pure nothrow @property @safe @nogc NBT_TYPE type() {
		return NBT_TYPE.LIST;
	}

	public override abstract pure nothrow @safe NamedTag rename(string name);

	public override abstract pure nothrow @property @safe @nogc ubyte childType();

	public @property @trusted Tag[] tags() {
		static if(is(T == Tag)) {
			return this.value;
		} else {
			Tag[] ret = new Tag[this.value.length];
			foreach(i, v; this.value) {
				ret[i] = cast(Tag)v;
			}
			return ret;
		}
	}

	public override pure nothrow @safe void encode(Stream stream) {
		stream.writeByte(this.childType);
		stream.writeLength(this.value.length);
		foreach(v ; this.value) {
			v.encode(stream);
		}
	}

	public override abstract pure nothrow @safe void decode(Stream stream);

	public override JSONValue toJSON() {
		JSONValue[] json;
		foreach(v ; this.value) {
			json ~= v.toJSON();
		}
		return JSONValue(json);
	}

	public override string toString() {
		return "List(" ~ to!string(this.value) ~ ")";
	}

}

/**
 * Array of named tags of the same type.
 * Example:
 * ---
 * new ListOf!String();           // String[] -> string[]
 * new ListOf!Compound();         // Compound[] -> NamedTag[string][]
 * new ListOf!(List!Compound)();  // Compound[][] -> NamedTag[string][][]
 * ---
 */
class List : ListImpl!Tag {

	private static immutable Tag function() pure nothrow @safe[ubyte] constructors;

	public static this() {
		foreach(i, T; Tags) {
			static if(is(T : Tag)) {
				constructors[i] = { return new T(); };
			}
		}
	}

	private ubyte child_type = 0;
	
	public pure nothrow @safe @nogc this(Tag[] tags...) {
		super(tags);
	}

	public override pure nothrow @safe NamedTag rename(string name) {
		return new Named!List(name, this.value);
	}

	public pure nothrow @property @safe @nogc bool valid() {
		ubyte type;
		if(this.child_type) {
			type = this.child_type;
		} else {
			if(this.value.length == 0) return false;
			type = this.value[0].type;
		}
		foreach(v ; this.value) {
			if(v.type != type) return false;
		}
		return true;
	}
	
	public final override pure nothrow @property @safe @nogc ubyte childType() {
		return this.child_type != 0 ? this.child_type : (this.length == 0 ? NBT_TYPE.END : this.value[0].type);
	}

	public override pure nothrow @safe void decode(Stream stream) {
		this.child_type = stream.readByte();
		immutable length = stream.readLength();
		auto ctor_ptr = this.child_type in constructors;
		if(ctor_ptr) {
			auto ctor = *ctor_ptr;
			foreach(i ; 0..length) {
				Tag tag = ctor();
				tag.decode(stream);
				this.value ~= tag;
			}
		}
	}
	
	public override bool opEquals(Object object) {
		if(cast(IList)object) {
			return this.value == (cast(IList)object).tags;
		}
		return false;
	}
	
	alias value this;
	
}

/// ditto
class ListOf(T:Tag) : ListImpl!T if(!isAbstractClass!T) {

	public static immutable ubyte tagType;

	public static this() {
		tagType = new T().type;
	}
	
	public pure nothrow @safe this(E)(E[] tags...) if(is(E == T) || is(E : typeof(T.value))) {
		static if(is(E == T)) {
			super(tags);
		} else {
			T[] nt;
			foreach(t ; tags) {
				nt ~= new T(t);
			}
			this(nt);
		}
	}

	public override pure nothrow @safe NamedTag rename(string name) {
		return new Named!(ListOf!T)(name, this.value);
	}
	
	public final override pure nothrow @property @safe @nogc ubyte childType() {
		return tagType;
	}

	public override pure nothrow @safe void decode(Stream stream) {
		// shouldn't be called
	}
	
	public T opCast(T)() if(is(T == List)) {
		return new List(cast(Tag[])this.value);
	}
	
	public override bool opEquals(Object object) {
		if(cast(IList)object) {
			return this.tags == (cast(IList)object).tags;
		}
		return false;
	}
	
	alias value this;
	
}

unittest {
	
	auto list = new ListOf!Byte([new Byte(1), new Byte(2)]);
	assert(cast(List)list !is null);
	assert(list.length == 2);
	assert(list[0] == 1 && list[1] == 2);
	assert(new ListOf!Int(1, 2, 3).tags == [new Int(1), new Int(2), new Int(3)]);
	
}

/**
 * Associative array of named tags (that can be of different types).
 * Example:
 * ---
 * auto compound = new Compound();
 * compound["string"] = new String("test");
 * compound["byte"] = new Byte(18);
 * ---
 */
class Compound : Tag {

	private NamedTag[] value;
	private string[] n_names; // to mantain order and avoid the use of associative array's opApply
	
	public pure nothrow @safe this(NamedTag[] tags...) {
		this.value = tags;
		foreach(tag ; tags) {
			this.n_names ~= tag.name;
		}
	}

	public override pure nothrow @property @safe @nogc NBT_TYPE type() {
		return NBT_TYPE.COMPOUND;
	}

	public override pure nothrow @safe NamedTag rename(string name) {
		return new Named!Compound(name, this.value);
	}

	protected pure nothrow @safe ptrdiff_t search(string cmp) {
		foreach(i, name; this.n_names) {
			if(name == cmp) return i;
		}
		return -1;
	}
	
	/**
	 * Checks whether or not a value is in the associative array.
	 * Returns: true if the key is found, false otherwise
	 */
	public pure nothrow @safe bool has(string name) {
		return this.search(name) >= 0;
	}
	
	/**
	 * Checks if the key is associated to a value and that the value
	 * is of the same type of T.
	 * Returns: true if the value is found and is of the type T, false otherwise
	 */
	public pure nothrow @safe bool has(T:Tag)(string name) {
		auto index = this.search(name);
		return index >= 0 && cast(T)this.value[index];
	}
	
	/**
	 * Gets a pointer to the element at the given index.
	 * Example:
	 * ---
	 * auto test = "test" in compound;
	 * if(test && cast(String)*test) {
	 *    assert(*test == "test");
	 * }
	 * ---
	 */
	public pure nothrow @safe Tag* opBinaryRight(string op : "in")(string name) {
		auto index = this.search(name);
		return index >= 0 ? &this.value[index] : null;
	}
	
	/**
	 * Gets the array of named tags (without the keys).
	 * To get the associative array of named tags use the
	 * property value.
	 * Example:
	 * ---
	 * Compound compound = new Compound([new Byte(1), new Int(2)]);
	 * assert(compound[] == compound.value.values);
	 * ---
	 */
	public pure nothrow @safe NamedTag[] opIndex() {
		return this.value;
	}
	
	/**
	 * Gets the element at the given index.
	 * Throws: RangeError if the given index is not in the array
	 * Example:
	 * ---
	 * assert(new Compound("", ["test": new String("test")])[0] == "test");
	 * ---
	 */
	public pure nothrow @safe Tag opIndex(string name) {
		return this.value[this.search(name)];
	}
	
	/**
	 * Gets the element at the given index, casting it to T.
	 * Returns: the named tag of type T or null if the conversion has failed
	 * Example:
	 * ---
	 * auto compound = new Compound("", ["test": new String("value")]);
	 * assert(is(typeof(compound["test"]) == NamedTag));
	 * assert(is(typeof(compound.get!String("test")) == String));
	 * ---
	 */
	public pure nothrow @safe T get(T:Tag)(string name) {
		return cast(T)this[name];
	}
	
	/**
	 * Sets the value at the given index.
	 * If the tag's name is different from the given index, the tag's
	 * name will be changed to the given index's one.
	 * Example:
	 * ---
	 * compound["string"] = new String("test", "test");
	 * assert(compound["string"].name == "string");
	 * compound["int"] = 12;
	 * compound["string"] = "Another string";
	 * ---
	 */
	public pure nothrow @safe void opIndexAssign(T)(T value, string name) if(is(T : Tag) || isNumeric!T || is(T == bool) || is(T == string) || is(T == ubyte[]) || is(T == byte[]) || is(T == int[])) {
		NamedTag tag;
		static if(is(T : Tag)) {
			tag = value.rename(name); // convert to named tag
		} else {
			static if(is(T == bool) || is(T == byte) || is(T == ubyte)) tag = new Named!Byte(name, value);
			else static if(is(T == short) || is(T == ushort)) tag = new Named!Short(name, value);
			else static if(is(T == int) || is(T == uint)) tag = new Named!Int(name, value);
			else static if(is(T == long) || is(T == ulong)) tag = new Named!Long(name, value);
			else static if(is(T == float)) tag = new Named!Float(name, value);
			else static if(is(T == double)) tag = new Named!Double(name, value);
			else static if(is(T == string)) tag = new Named!String(name, value);
			else static if(is(T == ubyte[]) || is(T == byte[])) tag = new Named!ByteArray(name, value);
			else tag = new Named!IntArray(name, value);
		}
		this[] = tag;
	}
	
	/**
	 * Sets the value using the named tag's name as the index.
	 * Example:
	 * ---
	 * auto compound = new Compound("");
	 * compound[] = new String("test", "value");
	 * assert(compound["test"] == "value");
	 * ---
	 */
	public pure nothrow @safe void opIndexAssign(NamedTag tag) {
		auto i = this.search(tag.name);
		if(i >= 0) {
			this.value[i] = tag;
		} else {
			this.value ~= tag;
			this.n_names ~= tag.name;
		}
	}
	
	/**
	 * Removed the given index from the array, if set.
	 * Example:
	 * ---
	 * auto compound = new Compound("", ["string", new String("test")]);
	 * assert("string" in compound);
	 * compound.remove("string");
	 * assert("string" !in compound);
	 * ---
	 */
	public @safe void remove(string name) {
		auto index = this.search(name);
		if(index >= 0) {
			this.value = this.value[0..index] ~ this.value[index+1..$];
			this.n_names = this.n_names[0..index] ~ this.n_names[index+1..$];
		}
	}
	
	/// Gets the length of the array (or the number of NamedTags in it).
	public final pure nothrow @property @safe @nogc size_t length() {
		return this.value.length;
	}
	
	/// Checks whether or not the array is empty (its length is equal to 0).
	public final pure nothrow @property @safe @nogc bool empty() {
		return this.length == 0;
	}
	
	/**
	 * Gets the keys (indexes of the array).
	 * Example:
	 * ---
	 * assert(new Compound("", ["a": new String("a"), "b": new String("b")]).keys == ["a", "b"]);
	 * ---
	 */
	public pure nothrow @property @safe @nogc string[] names() {
		return this.n_names;
	}
	
	/**
	 * Creates an exact duplicate of the tag.
	 */
	public @property Compound dup() {
		auto ret = new Compound();
		ret.value = this.value.dup;
		ret.n_names = this.n_names.dup;
		return ret;
	}

	public override pure nothrow @safe void encode(Stream stream) {
		foreach(tag ; this.value) {
			stream.writeNamedTag(tag);
		}
		stream.writeByte(NBT_TYPE.END);
	}

	public override pure nothrow @safe void decode(Stream stream) {
		NamedTag next;
		while((next = stream.readNamedTag()) !is null) {
			this[] = next;
		}
	}

	public override JSONValue toJSON() {
		JSONValue[string] json;
		foreach(tag ; this.value) {
			json[tag.name] = tag.toJSON();
		}
		return JSONValue(json);
	}
	
	public override bool opEquals(Object object) {
		if(cast(Compound)object) {
			Compound compound = cast(Compound)object;
			this.opEquals(compound.value);
		}
		return false;
	}
	
	public bool opEquals(NamedTag[] tags) {
		return this.value == tags;
	}

	public override string toString() {
		return "Compound(" ~ to!string(this.value) ~ ")";
	}
	
}

unittest {

	Compound compound = new Compound();

	compound["0"] = "string";
	compound[] = new Named!Int("int", 44);
	assert(cast(String)compound["0"]);
	assert(cast(Int)compound["int"]);
	assert(compound.get!String("0") == "string");
	assert(compound.get!Int("int") == 44);
	assert(compound == new Compound(new Named!Int("int", 44), new Named!String("0", "string")));
	
}
