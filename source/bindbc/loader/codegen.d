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

enum makeLibPaths = (string[] names, string[][string] platformNames=["": []], string[][string] platformPaths=["": []]) nothrow pure @safe{
	string[] namesFor(string platform){
		if(platform in platformNames) return platformNames[platform] ~ names;
		else return names;
	}
	string[] pathsFor(string platform){
		if(auto ret = platform in platformPaths) return *ret;
		else return null;
	}
	string[] ret;
	version(Windows){
		ret ~= pathsFor("Windows");
		foreach(n; namesFor("Windows")){
			ret ~= [
				n~`.dll`,
			];
		}
	}else version(OSX){
		ret ~= pathsFor("OSX");
		foreach(n; namesFor("OSX")){
			ret ~= [
				`lib`~n~`.dylib`,
				`/opt/homebrew/lib/lib`~n~`.dylib`,
				n,
				`/Library/Frameworks/`~n~`.framework/`~n,
				`/System/Library/Frameworks/`~n~`.framework/`~n,
			];
		}
	}else version(linux){
		ret ~= pathsFor("linux");
		foreach(n; namesFor("linux")){
			ret ~= [
				`lib`~n~`.so`,
			];
		}
	}else static assert(0, "BindBC-Loader does not have library search paths set up for this platform.");
	string joined = `[`;
	foreach(item; ret){
		joined ~= `"` ~ item ~ `",`;
	}
	return joined ~ `]`;
};

enum makeDynloadFns = (string name, string libNames, string[] bindModules) nothrow pure @safe{
	string dynloadFns = `
private SharedLib lib;

@nogc nothrow{
void unload`~name~`(){ if(lib != bindbc.loader.invalidHandle) lib.unload(); }

bool is`~name~`Loaded(){ return lib != bindbc.loader.invalidHandle; }

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
	if(lib == bindbc.loader.invalidHandle){
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
