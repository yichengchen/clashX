#!/bin/sh
SDK=macosx
PLATFORM=macosx
if [ "$GOARCH" == "arm64" ]; then
	CLANGARCH="arm64"
else
	CLANGARCH="x86_64"
fi

SDK_PATH=`xcrun --sdk $SDK --show-sdk-path`
CLANG=`xcrun --sdk $SDK --find clang`
exec "$CLANG" -arch $CLANGARCH -isysroot "$SDK_PATH" -mmacosx-version-min=10.12 "$@"
