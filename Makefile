#!/usr/bin/make -f
$(shell [ -d build ] || mkdir build)
appdir		 := apps
apps		 := Hangouts.app Trello.app Digg.app Vine.app
#apps		 := $(addsuffix .app, $(basename $(wildcard sites/*)))
#apps		 := $(patsubst %, %.app, $(basename $(wildcard sites/*)))
debug		 ?=
debug += -D APP2JSLOG -D SAFARIDBG -D WK2LOG -D DBGMENU
#^ need to make sure !release target
all: $(apps)
exec		 := build/MacPin.exec

VERSION		 := 1.1.0
LAST_TAG	 != git describe --abbrev=0 --tags
USER		 := kfix
REPO		 := MacPin
ZIP			 := $(REPO).zip
GH_RELEASE_JSON = '{"tag_name": "v$(VERSION)","target_commitish": "master","name": "v$(VERSION)","body": "MacPin build of version $(VERSION)","draft": false,"prerelease": false}'

swiftc		:= xcrun -sdk macosx swiftc
sdkpath		:= $(shell xcrun --show-sdk-path --sdk macosx)
frameworks	:= -F $(sdkpath)/System/Library/Frameworks -F build
modincdirs	:= -I build -L build -I objc
bridgehdrs	:= $(wildcard modules/*/objc-bridging.h)
bridgeopt	:= $(addprefix -import-objc-header , $(bridgehdrs))

modules/%/objc-bridging.h: ; #ignore missing bridge headers
build/%.objc-bridging.o: modules/%/objc-bridging.h
	env bash objc/bridge-maker.sh $< $@

build/%.exec: build/%.o build/%.objc-bridging.o 
	$(swiftc) $(debug) $(frameworks) $(modincdirs) \
		-Xlinker -rpath -Xlinker @executable_path/ \
		-emit-executable -o $@ $< $(wildcard build/$*.objc-bridging.o)

build/%.o: modules/%/main.swift build/lib%.dylib
	$(swiftc) $(debug) $(frameworks) $(bridgeopt) $(modincdirs) \
		-l$* -module-link-name $* -module-name $*Main \
		-emit-object -o $@ $<

build/lib%.dylib build/%.swiftmodule build/%.swiftdoc: modules/%/*.swift
	$(swiftc) $(debug) $(frameworks) $(modincdirs) $(bridgeopt) \
		-emit-library -o build/lib$*.dylib \
		-Xlinker -install_name -Xlinker @rpath/lib$*.dylib \
 		-emit-module -module-name $* -module-link-name $* -emit-module-path build/$*.swiftmodule \
		$(filter-out $(wildcard modules/*/main.swift), $+)

build/%.a: build/%.o
	ar rcs $@ $<

build/%.o: objc/%.m
	xcrun -sdk macosx clang -c $(frameworks) -fmodules -o $@ $<

icons/%.icns: icons/%.png
	python icons/AppleIcnsMaker.py -p $<

icons/%.icns: icons/WebKit.icns
	cp $< $@

# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
# https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html
%.app: $(exec) icons/%.icns sites/% entitlements.plist
	python2.7 -m bundlebuilder \
	--name=$* \
	--bundle-id=com.github.kfix.macpin.$* \
	--builddir=$(appdir) \
	--executable=$(exec) \
	--iconfile=icons/$*.icns \
	--file=sites/$*:Contents/Resources \
	build
	#install -d $(appdir)/$*.app/Contents/MacOS/modules
	#install $(modobjs) $(appdir)/$*.app/Contents/MacOS/modules
	install build/lib*.dylib $(appdir)/$*.app/Contents/MacOS
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $(appdir)/$*.app/Contents/Info.plist 
	plutil -replace CFBundleVersion -string "0.0.0" $(appdir)/$*.app/Contents/Info.plist
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $(appdir)/$*.app/Contents/Info.plist
	#true = NSSupportsAutomaticTermination NSSupportsSuddenTermination 
	-codesign -s - -f --entitlements entitlements.plist $(appdir)/$*.app && codesign -dv $(appdir)/$*.app
	-asctl container acl list -file $(appdir)/$*.app

install: $(apps)
	cd $(appdir); cp -R $+ ~/Applications

clean:
	-rm $(exec) *.o *.d *.zip 
	-cd build && rm *.o *.a *.dylib *.d *.swiftmodule *.swiftdoc *.exec
	-cd $(appdir) && rm -rf *.app 

uninstall:
	-defaults delete $(exec)
	-rm -rf ~/Library/Caches/com.github.kfix.$(exec).* ~/Library/WebKit/com.github.kfix.$(exec).* ~/Library/WebKit/$(exec)
	-rm -rf ~/Library/Saved\ Application\ State/com.github.kfix.macpin.*
	-rm -rf ~/Library/Preferences/com.github.kfix.macpin.*
	-cd ~/Applications; rm -rf $(apps)
	-defaults read com.apple.spaces app-bindings | grep com.githib.kfix.macpin.
	# open ~/Library/Preferences/com.apple.spaces.plist

test: $(exec)
	#-defaults delete $(exec)
	$< http://browsingtest.appspot.com

doc: $(exec) 
	echo ":print_module MacPin" | xcrun swift $(modincdirs) -deprecated-integrated-repl

nightly: $(exec) DYLD_FRAMEWORK_PATH=/Volumes/WebKit/WebKit.app/Contents/Frameworks/10.10
	-defaults delete $(exec)
	-rm -rf ~/Library/WebKit/$(exec)
	$<

tag:
	git tag -f -a v$(VERSION) -m 'release $(VERSION)'

$(ZIP): tag
	rm $(ZIP) || true
	cd $(appdir); zip -no-wild -r ../$@ $(apps) --exclude .DS_Store

release: clean $(apps) $(ZIP)
	git push -f --tags
	posturl=$$(curl --data $(GH_RELEASE_JSON) "https://api.github.com/repos/$(USER)/$(REPO)/releases?access_token=$(GITHUB_ACCESS_TOKEN)" | jq -r .upload_url | sed 's/[\{\}]//g') && \
	dload=$$(curl --fail -X POST -H "Content-Type: application/gzip" --data-binary "@$(ZIP)" "$$posturl=$(ZIP)&access_token=$(GITHUB_ACCESS_TOKEN)" | jq -r .browser_download_url | sed 's/[\{\}]//g') && \
	echo "$(REPO) now available for download at $$dload"

.PRECIOUS: icons/%.icns $(appdir)/%.app build/lib%.dylib
.PHONY: clean install uninstall test all tag release nightly doc
