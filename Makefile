#!/usr/bin/make -f
outdir				?= build

macpin				:= MacPin
bin_macpin			:= $(outdir)/MacOS/$(macpin)
lib_macpin			:= $(outdir)/Frameworks/lib$(macpin).dylib
macpin_apps			:= Hangouts Trello Digg Vine Facebook CloudPebble
macpin_sites		?= sites

appdir				?= $(outdir)/apps
//appdir				?= apps
apptgts				:= $(patsubst %,$(appdir)/%.app,$(macpin_apps))
allapps: $(apptgts)
appexec				:= $(bin_macpin)
#$(appdir)/%.app: appexec = $(macpin)
#$(appdir)/%.app: applib = $(libmacpin)
debug				?=
#exttgts			:= $(patsubst %,$(appdir)/%.appex,$(apps))

VERSION		 := 1.3.0
LAST_TAG	 != git describe --abbrev=0 --tags
USER		 := kfix
REPO		 := MacPin
ZIP			 := $(REPO).zip
GH_RELEASE_JSON = '{"tag_name": "v$(VERSION)","target_commitish": "master","name": "v$(VERSION)","body": "MacPin build of version $(VERSION)","draft": false,"prerelease": false}'

#verbose			:= -v
swiftc				:= xcrun -sdk macosx swiftc $(verbose)
sdkpath				:= $(shell xcrun --show-sdk-path --sdk macosx)
frameworks			:= -F $(sdkpath)/System/Library/Frameworks -F $(outdir)/Frameworks

$(bin_macpin): $(outdir)/Frameworks/libMacPin.dylib
$(lib_macpin): $(outdir)/obj/Prompt.o
$(lib_macpin): linklibs += -lPrompt.o
$(bin_macpin) $(lib_macpin): linklibs += -module-link-name MacPin
$(bin_macpin) $(lib_macpin): incmods += -I modules/Prompt -I modules/WebKitPrivates

$(appdir) $(outdir)/MacOS $(outdir)/Frameworks $(outdir)/obj: ; install -d $@

$(outdir)/MacOS/%: incmods = -I $(outdir)
$(outdir)/MacOS/%: linklibs = -L $(outdir)/Frameworks
$(outdir)/MacOS/%: execs/%.swift | $(outdir)/MacOS
	$(swiftc) $(debug) $(frameworks) $(incmods) $(linklibs) \
		-Xlinker -rpath -Xlinker @loader_path/../Frameworks \
		-module-name $*.MainExec \
		-emit-executable -o $@ $<

$(outdir)/Frameworks/lib%.dylib: linklibs = -L $(outdir)/Frameworks -L $(outdir)/obj
$(outdir)/Frameworks/lib%.dylib $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc: modules/%/*.swift | $(outdir)/Frameworks
	$(swiftc) $(debug) $(frameworks) $(incmods) $(linklibs) \
		-emit-library -o $@ \
		-Xlinker -install_name -Xlinker @rpath/lib$*.dylib \
 		-emit-module -module-name $* -emit-module-path $(outdir)/$*.swiftmodule \
		$(filter %.swift,$+)

$(outdir)/obj/%.a: $(outdir)/obj/%.o
	ar rcs $@ $<

$(outdir)/Frameworks/lib%.dylib: modules/%/*.m | $(outdir)/Frameworks
	xcrun -sdk macosx clang -ObjC $(frameworks) -fmodules -o $@ $+

$(outdir)/obj/%.o: modules/%/*.m | $(outdir)/obj
	xcrun -sdk macosx clang -ObjC -c $(frameworks) -fmodules -o $@ $+

#$(outdir)/%.ShareExtension.bundle: $(outdir)/%.ShareExtension/*.swift
#$(swiftc) -application-extension
# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/SystemExtensionKeys.html#//apple_ref/doc/uid/TP40014212-SW15

icons/%.icns: icons/%.png
	python icons/AppleIcnsMaker.py -p $<

icons/%.icns: icons/WebKit.icns
	cp $< $@

# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
# https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html
$(appdir)/%.app: $(bin_macpin) sites/%/* icons/%.icns $(macpin_sites)/% entitlements.plist $(lib_macpin) | $(appdir)
	python2.7 -m bundlebuilder \
	--name=$* \
	--bundle-id=com.github.kfix.$(macpin).$* \
	--builddir=$(appdir) \
	--executable=$(bin_macpin) \
	--iconfile=icons/$*.icns \
	--file=$(macpin_sites)/$*:Contents/Resources \
	$(addprefix --lib=,$(filter %.dylib,$+)) \
	build
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $@/Contents/Info.plist 
	plutil -replace CFBundleVersion -string "0.0.0" $@/Contents/Info.plist
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $@/Contents/Info.plist
	plutil -replace NSSupportsAutomaticTermination -bool true $@/Contents/Info.plist
	plutil -replace NSSupportsSuddenTermination -bool true $@/Contents/Info.plist
	plutil -replace SecTaskAccess -json [] $@/Contents/Info.plist
	plutil -replace SecTaskAccess.0 -string allowed $@/Contents/Info.plist
	plutil -replace CFBundleDocumentTypes -json [] $@/Contents/Info.plist
	/usr/libexec/PlistBuddy -c 'merge ftypes.plist :CFBundleDocumentTypes' -c save $@/Contents/Info.plist
	[ ! -f "$(macpin_sites)/$*/Makefile" ] || $(MAKE) -C $@/Contents/Resources
	for i in "$@/Contents/Frameworks/*.dylib $@"; do codesign -s - -f --entitlements entitlements.plist $$i; done
	#codesign -vvv -s - -f --deep --entitlements entitlements.plist $@
	codesign --display -r- --verbose=4 --entitlements :- $@
	-spctl --verbose=4 --assess --type execute $@
	-asctl container acl list -file $@

$(appdir)/%.share.appex: $(icons)/%.icns $(macpin_sites)/$*/appex.share.plist $(macpin_sites)/$*./appex.share.js icons/Resources
	python2.7 -m bundlebuilder \
	--name=$* \
	--bundle-id=com.github.kfix.$(macpin).$* \
	--outdir=$(appdir) \
	--executable=$(appexec) \
	--iconfile=icons/$*.icns \
	--file=$(macpin_sites)/$*:Contents/Resources \
	--file=icons/Resources:Contents/Resources \
	$(addprefix --lib=,$(filter %.dylib,$+)) \
	build
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $@/Contents/Info.plist 
	plutil -replace CFBundleVersion -string "1" $@/Contents/Info.plist
	plutil -replace CFBundlePackageType -string "XPC!" $@/Contents/Info.plist
	plutil -replace NSExtension -json "{}" $@/Contents/Info.plist
	/usr/libexec/PlistBuddy -c 'merge $(macpin_sites)/$*/appex.share.plist :NSExtension' -c save $@/Contents/Info.plist
	-codesign -s - -f --entitlements entitlements.plist $@ && codesign -dv $@
	-asctl container acl list -file $@

install: $(apptgts)
	cp -R $+ ~/Applications

clean:
	-cd $(appdir) && rm -rf *.app 
	-rm -rf $(outdir)

uninstall:
	-defaults delete $(appexec)
	-rm -rf ~/Library/Caches/com.github.kfix.$(macpin).* ~/Library/WebKit/com.github.kfix.$(macpin).* ~/Library/WebKit/$(macpin)
	-rm -rf ~/Library/Saved\ Application\ State/com.github.kfix.$(macpin).*
	-rm -rf ~/Library/Preferences/com.github.kfix.$(macpin).*
	-cd ~/Applications; rm -rf $(macpin_apps)
	-defaults read com.apple.spaces app-bindings | grep com.github.kfix.$(macpin).
	# open ~/Library/Preferences/com.apple.spaces.plist

test repl test.app: debug = -D SAFARIDBG -D DBGMENU
test: $(appexec)
	#-defaults delete $(macpin)
	($< http://browsingtest.appspot.com)

repl: $(appexec)
	($< -i)

test.app: $(appdir)/test.app
	#open -F -a $$PWD/$^ http://browsingtest.appspot.com
	#open -b com.github.kfix.$(macpin).test http://browsingtest.appspot.com
	#banner ':-}' | open -a $$PWD/$^ -f
	#-defaults delete com.github.kfix.$(macpin).test
	#($^/Contents/MacOS/test http://browsingtest.appspot.com)
	(open $^) &

# https://github.com/WebKit/webkit/blob/master/Tools/Scripts/webkitdirs.pm
# debug: $(appdir)/test.app

# need to gen static html with https://github.com/realm/jazzy
doc: $(appexec) 
	echo ":print_module $(macpin)" | xcrun swift $(modincdirs) -deprecated-integrated-repl

nightly: $(appexec) DYLD_FRAMEWORK_PATH=/Volumes/WebKit/WebKit.app/Contents/Frameworks/10.10
	-defaults delete $(macpin)
	-rm -rf ~/Library/WebKit/$(macpin)
	$<

#.safariextz: http://developer.streak.com/2013/01/how-to-build-safari-extension-using.html

tag:
	git tag -f -a v$(VERSION) -m 'release $(VERSION)'

$(ZIP): tag
	rm $(ZIP) || true
	zip -no-wild -r $@ $(apptgts) --exclude .DS_Store

ifneq ($(GITHUB_ACCESS_TOKEN),)
release: clean allapps $(ZIP)
	git push -f --tags
	posturl=$$(curl --data $(GH_RELEASE_JSON) "https://api.github.com/repos/$(USER)/$(REPO)/releases?access_token=$(GITHUB_ACCESS_TOKEN)" | jq -r .upload_url | sed 's/[\{\}]//g') && \
	dload=$$(curl --fail -X POST -H "Content-Type: application/gzip" --data-binary "@$(ZIP)" "$$posturl=$(ZIP)&access_token=$(GITHUB_ACCESS_TOKEN)" | jq -r .browser_download_url | sed 's/[\{\}]//g') && \
	echo "$(REPO) now available for download at $$dload"
else
release:
	@echo You need to export \$$GITHUB_ACCESS_TOKEN to make a release!
	@exit 1
endif

.PRECIOUS: icons/%.icns $(appdir)/%.app $(outdir)/Frameworks/lib%.dylib $(outdir)/obj/%.o $(outdir)/MacOS/%
.PHONY: clean install uninstall test test.app repl allapps tag release nightly doc
