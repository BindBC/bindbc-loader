/+
+            Copyright 2023 – 2024 Aya Partridge
+          Copyright 2018 - 2022 Michael D. Parker
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.loader.system;

deprecated("Please use `version(D_LP64)` instead; or in a larger if-statement use `(){ version(D_LP64) return true; else return false; }()`, or `(void*).sizeof == 8` instead")
enum bind64 = (void*).sizeof == 8;
deprecated("Please use `version(D_X32)` instead; or in a larger if-statement use `(){ version(D_X32) return true; else return false; }()`, or `(void*).sizeof == 4` instead")
enum bind32 = (void*).sizeof == 4;

deprecated("Please use `version(Windows)` instead; or in a larger if-statement use `(){ version(Windows) return true; else return false; }()` instead")
enum bindWindows = (){
	version(Windows) return true;
	else return false;
}();

deprecated("Please use `version(OSX)` instead; or in a larger if-statement use `(){ version(OSX) return true; else return false; }()` instead")
enum bindMac = (){
	version(OSX) return true;
	else return false;
}();

deprecated("Please use `version(linux)` instead; or in a larger if-statement use `(){ version(linux) return true; else return false; }()` instead")
enum bindLinux = (){
	version(linux) return true;
	else return false;
}();

deprecated("Please use `version(Posix)` instead; or in a larger if-statement use `(){ version(Posix) return true; else return false; }()` instead")
enum bindPosix = (){
	version(Posix) return true;
	else return false;
}();

deprecated("Please use `version(Android)` instead; or in a larger if-statement use `(){ version(Android) return true; else return false; }()` instead")
enum bindAndroid = (){
	version(Android) return true;
	else return false;
}();

deprecated("`bindIOS` is always false. Please use `version(iOS)` to check if your code is compiled for iOS instead")
enum bindIOS = false;

deprecated("`bindWinRT` is always false. Please use a custom version identifier (e.g. `version(WinRT)`) to check if your code is compiled for WinRT instead")
enum bindWinRT = false;

deprecated("Please use `version(OpenBSD)` instead; or in a larger if-statement use `(){ version(OpenBSD) return true; else return false; }()` instead")
enum bindOpenBSD = (){
	version(OpenBSD) return true;
	else return false;
}();

deprecated("Please use `version(FreeBSD)` instead; or in a larger if-statement use `(){ version(FreeBSD) return true; else return false; }()` instead")
enum bindFreeBSD = (){
	version(FreeBSD) return true;
	else return false;
}();

deprecated("Please use `version(BSD)` instead; or in a larger if-statement use `(){ version(BSD) return true; else return false; }()` instead")
enum bindBSD = (){
	version(FreeBSD)      return true;
	else version(OpenBSD) return true;
	else version(BSD)     return true;
	else return false;
}();
