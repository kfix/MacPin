#!/usr/bin/make -f
appdir		 := apps
apps		 := Hangouts.app Trello.app Digg.app Vine.app
appexec		 := build/MacOS/MacPin
#apps		 := $(addsuffix .app, $(basename $(wildcard sites/*)))
#apps		 := $(patsubst %, %.app, $(basename $(wildcard sites/*)))
debug		 ?=
debug		 += -D APP2JSLOG -D SAFARIDBG -D WK2LOG -D DBGMENU
#^ need to make sure !release target
#verbose		:= -driver-print-jobs
# ^ just a dry-run
#verbose		:= -v
all: $(apps)

VERSION		 := 1.1.0
LAST_TAG	 != git describe --abbrev=0 --tags
USER		 := kfix
REPO		 := MacPin
ZIP			 := $(REPO).zip
GH_RELEASE_JSON = '{"tag_name": "v$(VERSION)","target_commitish": "master","name": "v$(VERSION)","body": "MacPin build of version $(VERSION)","draft": false,"prerelease": false}'

swiftc		:= xcrun -sdk macosx swiftc $(verbose)
sdkpath		:= $(shell xcrun --show-sdk-path --sdk macosx)
frameworks	:= -F $(sdkpath)/System/Library/Frameworks -F build -F build/Frameworks
modincdirs	:= -I build -L build -L build/Frameworks
modincdirs  += $(addprefix -I ,$(patsubst %/,%,$(dir $(wildcard modules/*/module.modulemap))))

#build/%.appex
#$(swiftc) -application-extension
# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/SystemExtensionKeys.html#//apple_ref/doc/uid/TP40014212-SW15

build/MacOS/%: execs/%.swift build/Frameworks/lib%.dylib 
	install -d $(@D)
	$(swiftc) $(debug) $(frameworks) $(modincdirs) \
		-Xlinker -rpath -Xlinker @loader_path/../Frameworks \
		-module-link-name $* -module-name $*.MainExec \
		-emit-executable -o $@ $<

build/Frameworks/lib%.dylib build/%.swiftmodule build/%.swiftdoc: modules/%/*.swift
	install -d $(@D)
	$(swiftc) $(debug) $(frameworks) $(modincdirs) \
		-emit-library -o $@ \
		-Xlinker -install_name -Xlinker @rpath/lib$*.dylib \
 		-emit-module -module-name $* -module-link-name $* -emit-module-path build/$*.swiftmodule \
		$+

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
%.app: $(appexec) icons/%.icns sites/% entitlements.plist build/Frameworks/lib$(notdir $(appexec)).dylib
	python2.7 -m bundlebuilder \
	--name=$* \
	--bundle-id=com.github.kfix.$(notdir $(appexec)).$* \
	--builddir=$(appdir) \
	--executable=$(appexec) \
	--iconfile=icons/$*.icns \
	--file=sites/$*:Contents/Resources \
	$(addprefix --lib=,$(filter %.dylib,$+)) \
	build
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $(appdir)/$*.app/Contents/Info.plist 
	plutil -replace CFBundleVersion -string "0.0.0" $(appdir)/$*.app/Contents/Info.plist
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $(appdir)/$*.app/Contents/Info.plist
	plutil -replace NSSupportsAutomaticTermination -bool true $(appdir)/$*.app/Contents/Info.plist
	plutil -replace NSSupportsSuddenTermination -bool true $(appdir)/$*.app/Contents/Info.plist
	-codesign -s - -f --entitlements entitlements.plist $(appdir)/$*.app && codesign -dv $(appdir)/$*.app
	-asctl container acl list -file $(appdir)/$*.app

%.appex: %.app appex.plist
#	--bundle-id=com.github.kfix.macpin.$*.Extension

install: $(apps)
	cd $(appdir); cp -R $+ ~/Applications

clean:
	-rm -rf build
	-cd $(appdir) && rm -rf *.app 

uninstall:
	-defaults delete $(appexec)
	-rm -rf ~/Library/Caches/com.github.kfix.$(notdir $(appexec)).* ~/Library/WebKit/com.github.kfix.$(notdir $(appexec)).* ~/Library/WebKit/$(notdir $(appexec))
	-rm -rf ~/Library/Saved\ Application\ State/com.github.kfix.macpin.*
	-rm -rf ~/Library/Preferences/com.github.kfix.macpin.*
	-cd ~/Applications; rm -rf $(apps)
	-defaults read com.apple.spaces app-bindings | grep com.github.kfix.macpin.
	# open ~/Library/Preferences/com.apple.spaces.plist

test: $(appexec)
	#-defaults delete $(notdir appexec)
	$< http://browsingtest.appspot.com

doc: $(appexec) 
	echo ":print_module MacPin" | xcrun swift $(modincdirs) -deprecated-integrated-repl

nightly: $(appexec) DYLD_FRAMEWORK_PATH=/Volumes/WebKit/WebKit.app/Contents/Frameworks/10.10
	-defaults delete $(notdir $(appexec))
	-rm -rf ~/Library/WebKit/$(notdir $(appexec))
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

.PRECIOUS: icons/%.icns $(appdir)/%.app build/Frameworks/lib%.dylib
.PHONY: clean install uninstall test all tag release nightly doc
