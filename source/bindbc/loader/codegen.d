/+
+            Copyright 2022 – 2024 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.loader.codegen;

enum makeLibPaths = (string[] names, string[][string] platformNames=null, string[][string] platformPaths=null) nothrow pure @safe{
	string[] namesFor(string platform){
		if(platform in platformNames) return platformNames[platform] ~ names;
		else return names;
	}
	string[] pathsFor(string platform){
		if(auto ret = platform in platformPaths){
			return *ret ~ [""];
		}
		else return [""];
	}
	string[] ret;
	version(Windows){
		foreach(n; namesFor("Windows")){
			foreach(path; pathsFor("Posix")){
				ret ~= [
					path ~ n~`.dll`,
				];
			}
		}
	}else version(OSX){
		foreach(n; namesFor("OSX")){
			foreach(path; pathsFor("OSX")){
				ret ~= [
					path ~ `lib`~n~`.dylib`,
					path ~ n,
				];
			}
		}
		foreach(n; namesFor("OSX")){
			ret ~= [
				`/opt/homebrew/lib/lib`~n~`.dylib`,
				`/Library/Frameworks/`~n~`.framework/`~n,
				`/System/Library/Frameworks/`~n~`.framework/`~n,
			];
		}
	}else version(Posix){
		foreach(n; namesFor("Posix")){
			foreach(path; pathsFor("Posix")){
				ret ~= [
					path ~ `lib`~n~`.so`,
				];
			}
		}
	}else static assert(0, "BindBC-Loader does not have library search paths set up for this platform.");
	string joined = `[`;
	foreach(item; ret[0..$-1]){
		joined ~= `"` ~ item ~ `",`;
	}
	return joined ~ `"` ~ ret[$-1] ~ `"]`;
};
unittest{
	version(Windows){
		assert(mixin(makeLibPaths(["test"], null, [
			"Windows": ["windows_path/"],
		])) == ["windows_path/test.dll", "test.dll"]);
	}else version(OSX){
		assert(mixin(makeLibPaths(["test"], null, [
			"OSX": ["macos_path/"],
		])) == [
			`macos_path/libtest.dylib`,
			`macos_path/test`,
			`libtest.dylib`,
			`test`,
			`/opt/homebrew/lib/libtest.dylib`,
			`/Library/Frameworks/test.framework/test`,
			`/System/Library/Frameworks/test.framework/test`,
		]);
	}else version(Posix){
		assert(mixin(makeLibPaths(["test"], null, [
			"Posix": ["posix_path/"],
		])) == ["posix_path/libtest.so", "libtest.so"]);
	}
}

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
		dynloadFns ~= "\n\t\t"~mod~".bindModuleSymbols(lib);";
	}
	
	dynloadFns ~= `
		
		if(errCount != errorCount()) return LoadMsg.badLibrary;
		return LoadMsg.success;
	}
}`;
	
	return dynloadFns;
};
