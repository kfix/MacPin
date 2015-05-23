#!/bin/sh -x
cd $(dirname $0)
bundle=build/Release/AddressBookHangoutsPlugin.bundle 
[ -d $bundle ] || xcodebuild
cp -R $bundle ~/Library/Address\ Book\ Plug-Ins/
xcodebuild clean && rmdir -p build/AddressBookHangoutsPlugin.build/Release/
