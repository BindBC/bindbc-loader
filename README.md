# [BindBC-Loader](https://git.sleeping.town/BindBC/bindbc-loader)
This library contains the cross-platform shared library loading API used by the BindBC packages in their dynamic binding configurations. It is compatible with BetterC, `@nogc`, and `nothrow`, and intended as a replacement for [DerelictUtil](https://github.com/DerelictOrg/DerelictUtil), which does not provide the same level of compatibility.

The dynamic configuration of each official BindBC package implements its own public load function, which calls into the BindBC-Loader API to load function pointers from the appropriate shared library. BindBC-Loader is only for dynamic bindings, which have no link-time dependency on the bound library.

Users of packages dependent on BindBC-Loader need not be concerned with its configuration or the loader API. For such users, only the error handling API is of relevance. Anyone implementing a shared library loader on top of BindBC-Loader should be familiar with the entire public API and its configuration.

| Table of Contents |
|-------------------|
|[License](#license)|
|[Error handling](#error-handling)|
|[Configurations](#configurations)|
|[Default Windows search path](#default-windows-search-path)|

## License

BindBC-Loader&mdash;as well as every other library in the [BindBC project](https://github.com/BindBC)&mdash;is licensed under the [Boost Software License](https://www.boost.org/LICENSE_1_0.txt).

## Error handling
BindBC-Loader does not use exceptions. This decision was made for easier maintenance of the BetterC compatibility, and to provide a common API between both configurations. An application using a dependent package can check for errors consistently when compiling with and without BetterC.

The `errors()` function is most relevant to end-users of dependant libraries. `errorCount()`, and `resetErrors()` may also be occasionally useful. All three are found in the `bindbc.loader.sharedlib` module.

Errors are usually generated in two cases:
1. When a shared library cannot be loaded, usually because the shared library file cannot be found.
2. When a symbol in the library fails to load.

Multiple errors may be generated for each case, as attempts may be made to load a shared library from multiple paths, and failure to load one symbol does not immediately abort the load.

In the official BindBC bindings, the load function for each binding will return one of these values:
1. `noLibrary` if the library file fails to load.
2. `badLibrary` when an expected symbol fails to load.
3. `success`, or a version number.

For newer BindBC libraries these values belong to the `bindbc.loader.sharedlib.LoadMsg` enum. For older BindBC libraries these values belong to a binding-specific enum. For example, `SDLSupport.noLibrary` or `SDLSupport.badLibrary` for BindBC-SDL.

The function `bindbc.loader.sharedlib.errors()` returns an array of `ErrorInfo` structs that have two properties:

* `error`: For a library load failure, this is the name of the library. Otherwise, it is the string `"Missing Symbol"`.
* `message`: In the case of a library load failure, this contains a system-specific error message. Otherwise, it contains the name of the symbol that failed to load.

Here is an example of what error handling might look like when loading the SDL library with BindBC-SDL:
```d
import bindbc.sdl;

/*
Import the sharedlib module for error handling. Assigning an alias ensures that the
function names do not conflict with other public APIs. This isn't strictly necessary,
but the API names are common enough that they could appear in other packages.
*/
import loader = bindbc.loader.sharedlib;

bool loadLib(){
	LoadMsg ret = loadSDL();
	if(ret != sdlSupport){
		//Log the error info
		foreach(info; loader.errors){
			/*
			A hypothetical logging function. Note that `info.error` and
			`info.message` are null-terminated `const(char)*`, not `string`.
			*/
			logError(info.error, info.message);
		}
		
		//Optionally construct a user-friendly error message for the user
		string msg;
		if(ret == SDLSupport.noLibrary){
			msg = "This application requires the SDL library.";
		}else{
			SDL_version version;
			SDL_GetVersion(&version);
			msg = "Your SDL version is too low: "~
				itoa(version.major)~"."~
				itoa(version.minor)~"."~
				itoa(version.patch)~
				". Please upgrade to 2.0.16+.";
		}
		//A hypothetical message box function
		showMessageBox(msg);
		return false;
	}
	return true;
}
```

`errorCount()` returns the number of errors that have been generated. This might prove useful as a shortcut when loading multiple libraries:

```d
loadSDL();
loadOpenGL();
if(loader.errorCount > 0){
	//Log the errors
}
```

`resetErrors()` is available to enable alternate approaches to error handling. This clears the `ErrorInfo` array and resets the error count to 0.

Sometimes, failure to load one library may not be a reason to abort the program. Perhaps an alternative library can be used, or the functionality enabled by that library can be disabled. For such scenarios, it can be convenient to keep the error count specific to each library:

```d
if(loadSDL() != sdlSupport){
	//Log errors here
	
	//Start with a clean slate
	loader.resetErrors();
	//And then attempt to load GLFW instead
	if(loadGLFW() != glfwSupport){
		//Log errors and abort
	}
}
```

## Configurations
BindBC-Loader is not configured to compile with BetterC compatibility by default. Users of packages dependent on BindBC-Loader should not configure BindBC-Loader directly. Those packages have their own configuration options that will select the appropriate loader configuration.

Implementers of bindings using BindBC-Loader can make use of two configurations:
* `nobc`, which does not enable BetterC, and is the default.
* `yesbc` enables BetterC.

Binding implementers should typically provide four configuration options. Two for static bindings (BetterC and non-BetterC), and two for dynamic bindings using the `nobc` and `yesbc` configurations of BindBC-Loader:

|     ┌      |  DRuntime  |   BetterC   |
|-------------|------------|-------------|
| **Dynamic** | `dynamic`  | `dynamicBC` |
| **Static**  | `static`   | `staticBC`  |

Anyone using multiple BindBC packages with dynamic bindings must ensure that they are all configured to either use BetterC compatibility, or not. Configuring one BindBC package to use the BetterC configuration and another to use the non-BetterC configuration will cause conflicting versions of BindBC-Loader to be compiled, resulting in compiler or linker errors.

## Default Windows search path
Sometimes, it is desirable to place shared libraries in a subdirectory of the application. This is particularly common on Windows. Normally, any DLLs in a subdirectory can be loaded by prepending the subdirectory to the DLL name and passing that name to the appropriate load function (e.g. `loadSDL("dlls\\SDL2.dll")`). This is fine if the DLL has no dependency on any other DLLs, or if its dependencies are somewhere in the default DLL search path. If, however, its dependencies are also in the same subdirectory, then the DLL will fail to load&emdash;the system loader will be looking for the dependencies in the default DLL search path.

As a remedy, BindBC-Loader exposes the `setCustomLoaderSearchPath` function on Windows&endash;since other systems don't need to programmatically modify the shared library search path. To use it, call it prior to loading any DLLs and provide as the sole argument the path where the DLLs reside. Once this function is called, then the BindBC library's load function(s) may be called with no arguments as long as the DLL names have not been changed from the default.

An example with BindBC-SDL:

```d
import bindbc.sdl;
import bindbc.loader

//Assume the DLLs are stored in the "dlls" subdirectory
version(Windows) setCustomLoaderSearchPath("dlls");

if(loadSDL() < sdlSupport){ /*handle the error*/ }
if(loadSDL_Image() < sdlImageSupport){ /*handle the error*/ }

//Give SDL_image a chance to load libpng and libjpeg
auto flags = IMG_INIT_PNG | IMG_INIT_JPEG;
if(IMG_Init(flags) != flags){ /*handle the error*/ }

//Now reset to the default loader search path
version(Windows) setCustomLoaderSearchPath(null);
```

If the DLL name has been changed to something the loader does not recognise (e.g. `"MySDL.dll"`) then it will still need to be passed to the load function. (e.g. `loadSDL("MySDL.dll")`)

Please note that it is up to the programmer to ensure the path is valid. Generally, using a relative path like `"dlls"` or `".\\dlls"` is unreliable, as the program may be started in a directory that is different from the application directory. It is up to the programmer to ensure that the path is valid. The loader makes no attempt to fetch the current working directory or validate the path.

For details about how this function affects the system DLL search path, see the documentation of [the Win32 API function `SetDllDirectoryW`](https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setdlldirectoryw).