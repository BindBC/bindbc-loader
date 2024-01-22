/+
+            Copyright 2023 – 2024 Aya Partridge
+          Copyright 2018 - 2022 Michael D. Parker
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
/// Cross-platform interface to system APIs for manually loading C libraries.
module bindbc.loader.sharedlib;

import core.stdc.stdlib;
import core.stdc.string;

/*
TODO: less pointers, more types:
void* => HMODULE (Windows)
(convert these to null-terminated `char*` interally to avoid user input issues:)
char* => char[]
const(char)* => string
*/

enum LoadMsg{
	success,
	noLibrary,
	badLibrary,
}

/// Handle to a shared library
struct SharedLib{
	private void* _handle;
}

/// Indicates an uninitialized or unassigned handle.
enum invalidHandle = SharedLib.init;

/// Holds information about failures in loading shared libraries and their symbols.
struct ErrorInfo{
	private{
		char* _error;
		char* _message;
	}
	
	nothrow @nogc:
	/**
	Returns the string "Missing Symbol" to indicate a symbol load failure, and
	the name of a library to indicate a library load failure.
	*/
	@property const(char)* error() return const{ return _error; }
	
	/**
	Returns a symbol name for symbol load failures, and a system-specific error
	message for library load failures.
	*/
	@property const(char)* message() return const{ return _message; }
}

/*
TODO: wrap all the following behaviour into an object so that we can have 1 per library & there doesn't have to be one if there's 0 errors
and also use operator overloads to make this work more logically
*/
private{
	ErrorInfo[] _errors;
	size_t _errorCount;
}

@nogc nothrow:

/**
Returns a slice containing all `ErrorInfo` instances that have been accumulated by the
`load` and `bindSymbol` functions since the last call to `resetErrors`.
*/
const(ErrorInfo)[] errors(){
	return _errors[0 .. _errorCount];
}

/**
Returns the total number of `ErrorInfo` instances that have been accumulated by the
`load` and `bindSymbol` functions since the last call to `resetErrors`.
*/
size_t errorCount(){
	return _errorCount;
}

/**
Sets the error count to 0 and erases all accumulated errors. This function
does not release any memory allocated for the error list.
*/
void resetErrors(){
	_errorCount = 0;
	memset(_errors.ptr, 0, _errors.length * ErrorInfo.sizeof);
}

/*
void freeErrors(){
	free(_errors.ptr);
	_errors.length = _errorCount = 0;
}
*/

/**
Loads a symbol from a shared library and assigns it to a caller-supplied pointer.

Params:
	lib = a valid handle to a shared library loaded via the `load` function.
	ptr = a pointer to a function or variable whose declaration is
		appropriate for the symbol being bound (it is up to the caller to
		verify the types match).
	symbolName = the name of the symbol to bind.
*/
void bindSymbol(SharedLib lib, void** ptr, const(char)* symbolName){
	pragma(inline, false); // Without this, DMD can hang in release builds
	
	assert(lib._handle);
	auto sym = loadSymbol(lib._handle, symbolName);
	if(sym){
		*ptr = sym;
	}else{
		addErr("Missing Symbol", symbolName);
	}
}

/**
Formats a symbol using the Windows stdcall mangling if necessary before passing it on to
bindSymbol.

Params:
	lib = a valid handle to a shared library loaded via the `load` function.
	ptr = a reference to a function or variable of matching the template parameter
		type whose declaration is appropriate for the symbol being bound (it is up
		to the caller to verify the types match).
	symbolName = the name of the symbol to bind.
*/
void bindSymbol_stdcall(T)(SharedLib lib, ref T ptr, const(char)* symbolName){
	static if((){
		version(Windows) return (void*).sizeof == 4;
		else return false;
	}()){
		import core.stdc.stdio : snprintf;
		import std.traits : ParameterTypeTuple;
		
		uint paramSize(A...)(A args){
			size_t sum = 0;
			foreach(arg; args){
				sum += arg.sizeof;
				
				// Align on 32-bit stack
				if((sum & 3) != 0){
					sum += 4 - (sum & 3);
				}
			}
			return sum;
		}
		
		ParameterTypeTuple!f params;
		char[128] mangled;
		snprintf(mangled.ptr, mangled.length, "_%s@%d", symbolName, paramSize(params));
		symbolName = mangled.ptr;
	}
	bindSymbol(lib, cast(void**)&ptr,  symbolName);
}

/**
Loads a shared library from disk, using the system-specific API and search rules.

Params:
	libName = the name of the library to load. May include the full or relative path for the file.

Returns:
	A shared library, or `invalidHandle` on failure.
*/
SharedLib load(const(char)* libName){
	auto handle = loadLib(libName);
	if(handle){
		return SharedLib(handle);
	}else{
		addErr(libName, null);
		return invalidHandle;
	}
}

/**
Unloads a shared library from process memory.

Generally, it is not necessary to call this function at program exit, as the system will ensure
any shared libraries loaded by the process will be unloaded. However, it may be useful to call
this function to release shared libraries that are no longer needed by the program during runtime,
such as those that are part of a "hot swap" mechanism or an extension framework.
*/
void unload(ref SharedLib lib){
	if(lib._handle){
		unloadLib(lib._handle);
		lib = invalidHandle;
	}
}

private:
void allocErrs(){
	size_t newSize = _errorCount == 0 ? 16 : _errors.length * 2;
	auto errs = cast(ErrorInfo*)malloc(ErrorInfo.sizeof * newSize);
	if(!errs) exit(EXIT_FAILURE);
	
	if(_errorCount > 0){
		memcpy(errs, _errors.ptr, ErrorInfo.sizeof * _errors.length);
		free(_errors.ptr);
	}
	
	_errors = errs[0 .. newSize];
}

void copyString(char** dst, const(char)* src){
	*dst = cast(char*)malloc(strlen(src) + 1);
	strcpy(*dst, src);
}

void addErr(const(char)* errstr, const(char)* message){
	if(_errors.length == 0 || _errorCount >= _errors.length){
		allocErrs();
	}
	
	auto pinfo = &_errors[_errorCount];
	copyString(&pinfo._error, errstr);
	
	if(message){
		copyString(&pinfo._message, message);
	}else{
		sysError(pinfo);
	}
	++_errorCount;
}

version(Windows){
	import core.sys.windows.winbase;
	import core.sys.windows.winnt;
	private alias BOOL = int;
	private alias HMODULE = void*;
	extern(Windows) @nogc nothrow alias pSetDLLDirectory = BOOL function(const(char)*);
	pSetDLLDirectory setDLLDirectory;
	
	HMODULE loadLib(const(char)* name){
		return LoadLibraryA(name);
	}
	
	void unloadLib(void* lib){
		FreeLibrary(lib);
	}
	
	void* loadSymbol(void* lib, const(char)* symbolName){
		return GetProcAddress(lib, symbolName);
	}
	
	void wstringToString(char** dst, const(wchar)* src){
		import core.sys.windows.winnls;
		auto srcLen = lstrlenW(src);
		auto dstBuffLen = wchar.sizeof*srcLen + 1;
		*dst = cast(char*)malloc(dstBuffLen);
		WideCharToMultiByte(
			CP_UTF8,
			0,
			src,
			srcLen,
			*dst,
			cast(int)dstBuffLen,
			null,
			null,
		);
	}

	void sysError(ErrorInfo* pinfo){
		wchar* msgBuf;
		enum uint langID = MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT);
		
		FormatMessageW(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_SYSTEM |
			FORMAT_MESSAGE_IGNORE_INSERTS,
			null,
			GetLastError(),
			langID,
			cast(wchar*)&msgBuf,
			0,
			null,
		);
		
		if(msgBuf){
			wstringToString(&pinfo._message, msgBuf);
			LocalFree(msgBuf);
		}else{
			copyString(&pinfo._message, "Unknown Error");
		}
	}
	
	/**
	Adds a path to the default search path on Windows, replacing the path set in a previous
	call to the same function.
	
	Any path added via this function will be added to the default DLL search path as documented at
	https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setdlldirectoryw.
	
	Generally, when loading DLLs on a path that is not on the search path, e.g., from a subdirectory
	of the application, the path should be prepended to the DLL name passed to the load function,
	e.g., "dlls\\SDL2.dll". If `setCustomLoaderSearchPath(".\\dlls")` is called first, then the subdirectory
	will become part of the DLL search path and the path may be omitted from the load function. (Be
	aware that ".\\dlls" is relative to the current working directory, which may not be the application
	directory, so the path should be constructed appropriately.)
	
	Some DLLs may depend on other DLLs, perhaps even attempting to load them dynamically at run time
	(e.g., SDL2_image only loads dependencies such as libpng if it is initialized at run time with
	support for those dependencies). In this case, if the DLL and its dependencies are placed in a subdirectory and
	loaded as e.g., "dlls\\SDL2_image.dll", then the dependencies will not be found; the
	system loader will look for them on the regular DLL search path. When that happens, the solution
	is to call `setCustomLoaderSearchPath` with the subdirectory before initializing the library.
	
	Calling this function with `null` as the argument will reset the default search path.
	
	When the function returns `false`, the relevant `ErrorInfo` is added to the global error list and can
	be retrieved by looping through the array returned by the `errors` function.
	
	When placing DLLs in a subdirectory of the application, it should be considered good practice to
	call `setCustomLoaderSearchPath` to ensure all DLLs load properly. It should also be considered good
	practice to reset the default search path once all DLLs are loaded.
	
	This function is only available on Windows, so any usage of it should be preceded with
	`version(Windows)`.
	
	Params:
		path = the path to add to the DLL search path, or `null` to reset the default.
	
	Returns:
		`true` if the path was successfully added to the DLL search path, otherwise `false`.
	*/
	public bool setCustomLoaderSearchPath(const(char)* path){
		if(!setDLLDirectory){
			auto lib = load("Kernel32.dll");
			if(lib == invalidHandle) return false;
			lib.bindSymbol(cast(void**)&setDLLDirectory, "SetDllDirectoryA");
			if(!setDLLDirectory) return false;
		}
		return setDLLDirectory(path) != 0;
	}
}else version(Posix){
	import core.sys.posix.dlfcn;
	
	void* loadLib(const(char)* name){
		return dlopen(name, RTLD_NOW);
	}
	
	void unloadLib(void* lib){
		dlclose(lib);
	}
	
	void* loadSymbol(void* lib, const(char)* symbolName){
		return dlsym(lib, symbolName);
	}
	
	void sysError(ErrorInfo* pinfo){
		auto msg = dlerror();
		if(!msg) copyString(&pinfo._message, "Uknown Error");
		else copyString(&pinfo._message, msg);
	}
}else static assert(0, "bindbc-loader is not implemented on this platform.");
