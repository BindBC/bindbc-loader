/+
+            Copyright 2022 – 2023 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.loader.codegen;

enum LoadMsg{
	success,
	noLibrary,
	badLibrary,
}

enum makeDynloadFns = (string name, string libNames, string[] bindModules) nothrow pure @safe{
	string dynloadFns = `
private SharedLib lib;

@nogc nothrow{
void unload`~name~`(){ if(lib != invalidHandle) lib.unload(); }

bool is`~name~`Loaded(){ return lib != invalidHandle; }

LoadMsg load`~name~`(){
	enum libNamesCT = `~libNames~`;
	const(char)[][libNamesCT.length] libNames = libNamesCT;
	
	LoadMsg ret;
	foreach(name; libNames){
		ret = load`~name~`(name.ptr);
		if(ret == LoadMsg.success) break;
	}
	return ret;
}

LoadMsg load`~name~`(const(char)* libName){
	lib = bindbc.loader.load(libName);
	if(lib == invalidHandle){
		return LoadMsg.noLibrary;
	}
	
	auto errCount = errorCount();
`;
	
	foreach(mod; bindModules){
		dynloadFns ~= "\n\t"~mod~".bindModuleSymbols(lib);";
	}
	
	dynloadFns ~= `
	
	if(errCount != errorCount()) return LoadMsg.badLibrary;
	return LoadMsg.success;
}
}`;
	
	return dynloadFns;
};
