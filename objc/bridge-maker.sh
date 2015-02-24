#!/usr/bin/env bash
hdrobjs=""
[ ! -f $1 ] || while read dot hdrfile; do
	[ ! -f ${hdrfile/.h/.m} ] || hdrobjs+=build/$(basename ${hdrfile/.h/.o})
done < <(clang -I ./objc/ -E -H -fmodules -ObjC $1 -o /dev/null 2>&1)

echo $hdrobjs;
if [ -x "$hdrobjs" ]; then
	set -x
	make $hdrobjs
	xcrun -sdk macosx clang -o $2 $hdrobjs
fi
