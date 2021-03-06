#!/bin/sh
# runcocoa.sh - Run any Cocoa code from the command line
# 
# Michael Tyson, A Tasty Pixel <michael@atastypixel.com>
#

#  Check parameters and set settings
ccflags="";
includes="";
usegdb=;
usearc=yes;
ios=;
file=;
includemain=yes;
while [ "${1:0:1}" = "-" ]; do
	if [ "$1" = "-include" ]; then
		shift;
		printf -v includes "$includes\n#import <$1>";
	elif [ "$1" = "-gdb" ]; then
		usegdb=yes;
	elif [ "$1" = "-ios" ]; then
		ios=yes;
	elif [ "$1" = "-nomain" ]; then
		includemain=;
	elif [ "$1" = "-noarc" ]; then
		usearc=;
	elif [ "$1" = "-file" ]; then
		file="$2";
	else
		ccflags="$ccflags $1 $2";
		shift;
	fi;
	shift;
done;

# Read the code from the commandline or from a file
commands=$*
if [ ! "$commands" ]; then
	commands="`cat`"
elif [ "$file" ]; then
	commands=`cat $file`
fi

if [ "$ios" ]; then
	printf -v includes "$includes\n#import <Foundation/Foundation.h>\n#import <UIKit/UIKit.h>";
else
	printf -v includes "$includes\n#import <Cocoa/Cocoa.h>";
fi

# Use the appropriate template
if [ "$includemain" ]; then
	if [ "$usearc" ]; then
		cat > /tmp/runcocoa.m <<-EOF
		$includes
		int main(int argc, char *argv[]) {
			@autoreleasepool {
			  $commands;  
			}
		}
		EOF
	else
		cat > /tmp/runcocoa.m <<-EOF
		$includes
		int main (int argc, const char * argv[]) {
			NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		  	$commands;
		  	[pool drain];
		  	return 0;
		}
		EOF
	fi
else
	cat > /tmp/runcocoa.m <<-EOF
		$includes
		$commands;
	EOF
fi

if [ "$ios" ]; then
	export PATH="/Applications/Xcode.app/Contents/iPhoneSimulator.platform/Developer/usr/bin:/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin"
	compiler="/usr/bin/env llvm-gcc \
				-x objective-c -arch i386 -fmessage-length=0 -pipe -std=c99 -fpascal-strings -O0 \
				-isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.1.sdk -fexceptions -fasm-blocks \
				-mmacosx-version-min=10.6 -gdwarf-2 -fvisibility=hidden -fobjc-abi-version=2 -fobjc-legacy-dispatch -D__IPHONE_OS_VERSION_MIN_REQUIRED=40000 \
				-Xlinker -objc_abi_version -Xlinker 2 -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreText";
else
	export MACOSX_DEPLOYMENT_TARGET=10.6
	compiler="/usr/bin/env clang -O0 -std=c99 -framework Foundation -framework Cocoa";
	if [ "$usearc" ]; then
		compiler=$compiler" -fobjc-arc";
	fi
fi

if ! $compiler /tmp/runcocoa.m $ccflags -o /tmp/runcocoa-output; then
	exit 1;
fi

if [ "$ios" ]; then
	DYLD_ROOT_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.1.sdk" /tmp/runcocoa-output
elif [ "$usegdb" ]; then
	echo 'run; bt;' > /tmp/runcocoa-gdb
	gdb -x /tmp/runcocoa-gdb -e /tmp/runcocoa-output
	rm /tmp/runcocoa-gdb
else
	/tmp/runcocoa-output
fi
rm /tmp/runcocoa-output /tmp/runcocoa.m 2>/dev/null
