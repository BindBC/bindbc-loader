/+
+            Copyright 2023 – 2023 Aya Partridge
+          Copyright 2018 - 2022 Michael D. Parker
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module bindbc.loader.system;

deprecated:
enum bind64 = (void*).sizeof == 8;
enum bind32 = (void*).sizeof == 4;

enum bindWindows = (){
	version(Windows) return true;
	else return false;
}();

enum bindMac = (){
	version(OSX) return true;
	else return false;
}();

enum bindLinux = (){
	version(linux) return true;
	else return false;
}();

enum bindPosix = (){
	version(Posix) return true;
	else return false;
}();

enum bindAndroid = (){
	version(Android) return true;
	else return false;
}();

enum bindIOS = false;

enum bindWinRT = false;

version(FreeBSD) {
	enum bindBSD = true;
	enum bindFreeBSD = true;
	enum bindOpenBSD = false;
}else version(OpenBSD) {
	enum bindBSD = true;
	enum bindFreeBSD = false;
	enum bindOpenBSD = true;
}else version(BSD) {
	enum bindBSD = true;
	enum bindFreeBSD = false;
	enum bindOpenBSD = false;
}else{
	enum bindBSD = false;
	enum bindFreeBSD = false;
	enum bindOpenBSD = false;
}
