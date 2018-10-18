# bindbc-loader
This project contains the cross-platform shared library loading API used by the BindBC packages in their dynamic binding configurations. It is compatible with `-betterC`, `nothrow`, and `@nogc`, and intended as a replacement for [DerelictUtil](https://github.com/DerelictOrg/DerelictUtil), which provides no such compatibility.

Each BindBC package implements its own public load function which calls into the `bindbc-loader` API to load the C shared library to which the package binds. Packages compiled in their static binding configuration do not use `bindbc-loader`, as client aplilcations are required to be linked with the shared or static version of the C library in that scenario. `bindbc-loader` is only for dynamic bindings, which have no link-time dependency on a bound library.

Users of packages dependent on `bindbc-loader` need not be concerned with its configuration or the loader API. For such users, only the error handling API is of relevance. Anyone implementing a shared library loader on top of `bindbc-loader` should be familiar with the entire API and its configuration. Since error handling will be of concern to most users, it is covered first.

## Error handling
`bindbc-loader` does not use exceptions. This decision was made for easier maintenance of the `-betterC` compatibility and to provide a common API between both configurations. An application using a dependent package can check for errors consistently when compiling with and without `-betterC`.

There is one function of primary relevance to end users of dependent libraries: `errors`. The functions `errorCount` and `resetErrors` may also sometimes prove useful. All three are found in the `bindbc.loader.sharedlib` module.

Errors are generated in two cases: when a shared library file fails to load and when a symbol in the library fails to load. Multiple errors can be generated in each case, as attempts may be made to load a shared library from multiple paths, and failure to load one symbol does not abort the load.

The load function for each binding in the official BindBC group of bindings will return the values `noLibrary` when the file fails to load and `badLibrary` when an expected symbol fails to load. These values belong to a binding-specific `enum` namespace, e.g. `SDLSupport.noLibrary` and `SDLSupport.badLibrary` in `bindbc-sdl`. A successful load is indicated by another value from the same namespace indicating the version of the library that was loaded, which should generally equate to a the version the binding was configured at compile time to load. Please read the READEME for each BindBC binding to use for the specifics and any special cases.

The function `bindbc.loader.sharedlib.errors` returns an array of `ErrorInfo` instances. This is a struct that has two properties:

* `error` - if the error is the result of a library load failure, this is the name of the library; otherwise it is the string `"Missing Symbol"`.
* `message` - in the case of a library load failure, this contains a system-specific error message; otherwise it contains the name of the symbol that failed to load.

Here is an example of what error handling might look like when loading the SDL library with `bindbc-sdl`:

```d
// Import the dependent package
import bindbc.sdl;

/* Import the sharedlib module for error handling. Assigning an alias
 ensures the function names do not conflict with other public APIs
 and makes it obvious that the functions belong to the loader rather
 than bindbc.sdl. */
import loader = bindbc.loader.sharedlib;

bool loadLib() {
    // Compare the return value of loadSDL with the global `sdlSupport`
    // constant, which is configured at compile time for a specific
    // version of SDL.
    SDLSupport ret = loadSDL();
    if(ret != sdlSupport) {
        // Log the error info
        foreach(info; loader.errors) {
            // A hypothetical logging routine
            logError(info.error, info.message);
        }

        // Construct a user-friendly error message for the user
        string msg;
        if(ret == SDLSupport.noLibrary) {
            msg = "This application requires the SDL library.";
        } else {
            msg = "The version of the SDL library on your system is too low. Please upgrade."
        }
        showMessageBox(msg);
        return false;
    }
    return true;
}
```

`errorCount` returns the number length of array returned by `errors`. This might prove useful as a shortcut when loading multiple libraries:

```d
loadSDL();
loadOpenGL();
if(loader.errorCount > 0) {
    // Log the errors
}
```

`resetErrors` is available to enable alternate approaches to error handling. This clears the `ErrorInfo` array and resets the error count to `0`.

Sometimes, failure to load one library may not be a reason to abort the program. Perhaps an alternate library can be used, or the functionality enabled by that library can be disabled. For such scenarios, it can be convenient to keep the error count specific to each library:

```d
if(loadSDL != sdlSupport) {
    // Log errors

    // Attempt to load glfw instead, but start with a clean slate.
    loader.resetErrors();
    if(loadGLFW() != glfwSupport) {
        // Log errors and abort
    }
}
```

## Configuration
`bindbc-loader` is not configured to compile with `-betterC` compatibility by default. Users of packages dependent on `bindbc-loader` should not attempt to configure `bindbc-loader` directly. Those packages will have their own configuration options that will select the appropriate loader configuration.

Implementors of bindings using `bindbc-loader` can make use of two configurations: `nobc` and `yesbc`. The former, which does not enable `-betterC`, is the default. The latter enables `-betterC`. Binding implementors typically will provide four configuration options: two for static bindings (`nobc` and `yesbc` versions) and two for dynamic bindings (`nogc` and `yesbc` versions).

Anyone using multiple BindBC packages must ensure that they are all configured with the same `-betterC` option. Configuring one BindBC package to use the `nobc` configuration and another to use the `yesbc` configuration will cause conflicting versions of `bindbc-loader` to be compiled, resulting either in compiler or linker errors.