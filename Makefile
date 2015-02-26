#!/usr/bin/make -f
appdir		 := apps
apps		 := Hangouts Trello Digg Vine
appexec		 := build/MacOS/MacPin
debug		 ?=
#debug		 += -D APP2JSLOG -D SAFARIDBG -D WK2LOG -D DBGMENU
#^ need to make sure !release target
#verbose		:= -driver-print-jobs
# ^ just a dry-run
#verbose		:= -v
allapps		 := $(patsubst %,$(appdir)/%.app,$(apps))
allapps:	 $(allapps)

VERSION		 := 1.2.0
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
build/Frameworks/lib%.dylib: modules/%/*.m
	install -d $(@D)
	xcrun -sdk macosx clang -c $(frameworks) -fmodules -o $@ $<

#build/%.ShareExtension.bundle: build/%.ShareExtension/*.swift
#$(swiftc) -application-extension
# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/SystemExtensionKeys.html#//apple_ref/doc/uid/TP40014212-SW15

icons/%.icns: icons/%.png
	python icons/AppleIcnsMaker.py -p $<

icons/%.icns: icons/WebKit.icns
	cp $< $@

# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
# https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html
$(appdir)/%.app: $(appexec) icons/%.icns sites/% entitlements.plist build/Frameworks/lib$(notdir $(appexec)).dylib
	python2.7 -m bundlebuilder \
	--name=$* \
	--bundle-id=com.github.kfix.$(notdir $(appexec)).$* \
	--builddir=$(appdir) \
	--executable=$(appexec) \
	--iconfile=icons/$*.icns \
	--file=sites/$*:Contents/Resources \
	$(addprefix --lib=,$(filter %.dylib,$+)) \
	build
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $@/Contents/Info.plist 
	plutil -replace CFBundleVersion -string "0.0.0" $@/Contents/Info.plist
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $@/Contents/Info.plist
	plutil -replace NSSupportsAutomaticTermination -bool true $@/Contents/Info.plist
	plutil -replace NSSupportsSuddenTermination -bool true $@/Contents/Info.plist
	-codesign -s - -f --entitlements entitlements.plist $@ && codesign -dv $@
	-asctl container acl list -file $@

$(appdir)/%.appex: $(appdir)/%.app build/%.ShareExtension.bundle appex.plist
#	--bundle-id=com.github.kfix.macpin.$*.Extension

install: allapps
	cd $(appdir); cp -R $+ ~/Applications

clean:
	-rm -rf build
	-cd $(appdir) && rm -rf *.app 

uninstall:
	-defaults delete $(appexec)
	-rm -rf ~/Library/Caches/com.github.kfix.$(notdir $(appexec)).* ~/Library/WebKit/com.github.kfix.$(notdir $(appexec)).* ~/Library/WebKit/$(notdir $(appexec))
	-rm -rf ~/Library/Saved\ Application\ State/com.github.kfix.$(notdir $(appexec)).*
	-rm -rf ~/Library/Preferences/com.github.kfix.$(notdir $(appexec)).*
	-cd ~/Applications; rm -rf $(apps)
	-defaults read com.apple.spaces app-bindings | grep com.github.kfix.$(notdir $(appexec).
	# open ~/Library/Preferences/com.apple.spaces.plist

test: $(appexec)
	#-defaults delete $(notdir $(appexec))
	$< http://browsingtest.appspot.com

doc: $(appexec) 
	echo ":print_module $(notdir $(appexec))" | xcrun swift $(modincdirs) -deprecated-integrated-repl

nightly: $(appexec) DYLD_FRAMEWORK_PATH=/Volumes/WebKit/WebKit.app/Contents/Frameworks/10.10
	-defaults delete $(notdir $(appexec))
	-rm -rf ~/Library/WebKit/$(notdir $(appexec))
	$<

tag:
	git tag -f -a v$(VERSION) -m 'release $(VERSION)'

$(ZIP): tag
	rm $(ZIP) || true
	zip -no-wild -r $@ $(allapps) --exclude .DS_Store

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

.PRECIOUS: icons/%.icns $(appdir)/%.app build/Frameworks/lib%.dylib
.PHONY: clean install uninstall test allapps tag release nightly doc
