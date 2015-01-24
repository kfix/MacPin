#!/usr/bin/make -f
exec := macpin
appdir := apps
apps := Hangouts.app Trello.app Digg.app
#apps := $(addsuffix .app, $(basename $(wildcard sites/*)))
debug ?=
debug += -D APP2JSLOG

VERSION := 1.0.0
LAST_TAG != git describe --abbrev=0 --tags
USER := kfix
REPO := MacPin
ZIP := $(exec).zip
GH_RELEASE_JSON = '{"tag_name": "v$(VERSION)","target_commitish": "master","name": "v$(VERSION)","body": "MacPin build of version $(VERSION)","draft": false,"prerelease": false}'

all: $(apps)

%-objc-bridging.h:
	touch $*-objc-bridging.h
	#need to parse this to find .m's to compile

# http://stackoverflow.com/a/24154763/3878712
%.o: %.swift
	xcrun -sdk macosx swiftc -c $(debug) -F $(shell xcrun --show-sdk-path)/System/Library/Frameworks -import-objc-header $*-objc-bridging.h -o $@ $<

%.o: %.m
	xcrun -sdk macosx clang -c -F $(shell xcrun --show-sdk-path)/System/Library/Frameworks -fmodules -o $@ $<

$(exec): $(exec).o 
	xcrun -sdk macosx swiftc -o $@ $<

icons/%.icns: icons/%.png
	python icons/AppleIcnsMaker.py -p $<

icons/%.icns: icons/WebKit.icns
	cp $< $@

# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
%.app: $(exec) icons/%.icns sites/% sites/$(exec)_onload.js entitlements.plist
	python2.7 -m bundlebuilder \
	--name=$* \
	--bundle-id=com.github.kfix.$(exec).$* \
	--builddir=$(appdir) \
	--executable=$(exec) \
	--iconfile=icons/$*.icns \
	--file=sites/$*:Contents/Resources \
	--file=sites/$(exec)_onload.js:Contents/Resources \
	build
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $(appdir)/$*.app/Contents/Info.plist 
	plutil -replace CFBundleVersion -string "0.0.0" $(appdir)/$*.app/Contents/Info.plist
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $(appdir)/$*.app/Contents/Info.plist
	[ -z "$(debug)" ] || codesign -s - -f --entitlements entitlements.plist $(appdir)/$*.app && codesign -dv $(appdir)/$*.app

install: $(apps)
	cd $(appdir); cp -R $+ ~/Applications

clean:
	rm -rf $(exec) *.o *.zip $(appdir)/*.app

uninstall:
	defaults delete $(exec) || true
	rm -rf ~/Library/Caches/com.github.kfix.$(exec).* ~/Library/WebKit/com.github.kfix.$(exec).* ~/Library/WebKit/$(exec)
	rm -rf ~/Library/Saved\ Application\ State/com.github.kfix.macpin.*
	cd ~/Applications; rm -rf $(apps)
	defaults read com.apple.spaces app-bindings | grep com.githib.kfix.macpin. || true
	# open ~/Library/Preferences/com.apple.spaces.plist

install_exec: $(exec)
	[ -z "$(DESTDIR)" ] || install $(exec) $(DESTDIR)/

test: $(exec)
	#defaults delete $(exec)
	$(exec)

Xcode:
	cd $@
	cmake -G Xcode
	open MacPin.xcodeproj

tag:
	git tag -f -a v$(VERSION) -m 'release $(VERSION)'

$(ZIP): tag
	git archive --format=zip --output=$@ v$(VERSION) apps sites $(exec) *.swift *.h *.m Makefile

release: $(ZIP)
	git push -f --tags
	posturl=$$(curl --data $(GH_RELEASE_JSON) "https://api.github.com/repos/$(USER)/$(REPO)/releases?access_token=$(GITHUB_ACCESS_TOKEN)" | jq -r .upload_url | sed 's/[\{\}]//g') && \
	dload=$$(curl --fail -X POST -H "Content-Type: application/gzip" --data-binary "@$(ZIP)" "$$posturl=$(ZIP)&access_token=$(GITHUB_ACCESS_TOKEN)" | jq -r .browser_download_url | sed 's/[\{\}]//g') && \
	echo "$(REPO) now available for download at $$dload"

.PRECIOUS: icons/%.icns $(appdir)/%.app
.PHONY: clean install uninstall install_exec Xcode test all tag release
