#!/usr/bin/make -rf
builddir			?= build
# scans modules/ and defines cross: target and vars: outdir, platform, arch, sdk, target, objs, execs, incdirs, libdirs, linklibs, frameworks
include Makefile.eXcode

# now layout the MacPin .apps to generate
macpin				:= MacPin
macpin_sites		?= sites

template_bundle_id	:= com.github.kfix.MacPin
icondir				:= icons

installdir			:= ~/Applications
appsig				:= kfix@github.com
# https://developer.apple.com/library/mac/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html#//apple_ref/doc/uid/TP40005929-CH4-SW13
#appsig				:= -
# ^ ad-hoc, not so great

appdir				?= $(outdir)/apps
appnames			= $(patsubst $(macpin_sites)/%,%.app,$(wildcard $(macpin_sites)/*))
gen_apps			= $(patsubst $(macpin_sites)/%,$(appdir)/%.app,$(wildcard $(macpin_sites)/*))
#gen_action_exts	= $(patsubst %,$(appdir)/%.appex,$(apps))
$(info Buildable MacPin apps: $(gen_apps))

allapps install: $(gen_apps)
zip test apirepl tabrepl wknightly $(gen_apps): $(execs)
test apirepl tabrepl test.app test.ios: debug := -D SAFARIDBG -D DBGMENU -D APP2JSLOG
wknightly: DYLD_FRAMEWORK_PATH=/Volumes/WebKit/WebKit.app/Contents/Frameworks/10.10
noop: ;

ifeq ($(IS_A_REMAKE),)
# parent make invocation
else
#submake
endif

# github settings for release: target
#####
VERSION		 := 1.3.0
LAST_TAG	 != git describe --abbrev=0 --tags
USER		 := kfix
REPO		 := MacPin
ZIP			 := $(REPO).zip
GH_RELEASE_JSON = '{"tag_name": "v$(VERSION)","target_commitish": "master","name": "v$(VERSION)","body": "MacPin build of version $(VERSION)","draft": false,"prerelease": false}'
#####

$(icondir)/%.icns: $(icondir).%.png
	python icons/AppleIcnsMaker.py -p $<

$(icondir)/%.icns: $(icondir)/WebKit.icns
	cp $< $@

# OSX apps
$(appdir): ; install -d $@

$(appdir)/%.app/Contents/Info.plist: | $(outdir)/Contents
# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
# https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html

#$(appdir)/%.app/Contents/MacOS $(appdir)/%.app/Contents/Resources $(appdir)/%.app/Contents/Frameworks: ; install -d $@
$(appdir)/%.app: $(macpin_sites)/%/* $(icondir)/%.icns $(macpin_sites)/% entitlements.plist ftypes.plist | $(appdir)
	python2.7 -m bundlebuilder \
	--name=$* \
	--bundle-id=$(template_bundle_id).$* \
	--builddir=$(appdir) \
	$(addprefix --executable=,$(filter $(outdir)/exec/%,$^)) \
	--iconfile=$(icondir)/$*.icns \
	--file=$(macpin_sites)/$*:Contents/Resources \
	$(addprefix --lib=,$(filter %.dylib,$^)) \
	$(addprefix --lib=,$(wildcard $(outdir)/Frameworks/*.dylib)) \
	build
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $@/Contents/Info.plist 
	plutil -replace CFBundleVersion -string "0.0.0" $@/Contents/Info.plist
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $@/Contents/Info.plist
	plutil -replace NSSupportsAutomaticTermination -bool true $@/Contents/Info.plist
	plutil -replace NSSupportsSuddenTermination -bool true $@/Contents/Info.plist
	#plutil -replace SecTaskAccess -json [] $@/Contents/Info.plist
	#plutil -replace SecTaskAccess.0 -string allowed $@/Contents/Info.plist
	plutil -replace CFBundleDocumentTypes -json [] $@/Contents/Info.plist
	/usr/libexec/PlistBuddy -c 'merge ftypes.plist :CFBundleDocumentTypes' -c save $@/Contents/Info.plist
	[ ! -f "$(macpin_sites)/$*/Makefile" ] || $(MAKE) -C $@/Contents/Resources
	#for i in "$@/Contents/Frameworks/*.dylib $@"; do codesign -s - -f --ignore-resources --entitlements entitlements.plist $$i; done
	codesign --verbose=4 -s $(appsig) -f --deep --ignore-resources --entitlements entitlements.plist $@
	codesign --display -r- --verbose=4 --entitlements :- $@
	-spctl --verbose=4 --assess --type execute $@
	-asctl container acl list -file $@

$(appdir)/%.share.appex: $(icons)/%.icns $(macpin_sites)/$*/appex.share.plist $(macpin_sites)/$*./appex.share.js icons/Resources
	python2.7 -m bundlebuilder \
	--name=$* \
	--bundle-id=$(template_bundle_id).$(macpin).$* \
	--outdir=$(appdir) \
	$(addprefix --executable=,$(filter $(outdir)/exec/%,$^)) \
	--iconfile=icons/$*.icns \
	--file=$(macpin_sites)/$*:Contents/Resources \
	--file=icons/Resources:Contents/Resources \
	$(addprefix --lib=,$(filter %.dylib,$^)) \
	$(addprefix --lib=,$(wildcard $(outdir)/Frameworks/*.dylib)) \
	build
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" $@/Contents/Info.plist 
	plutil -replace CFBundleVersion -string "1" $@/Contents/Info.plist
	plutil -replace CFBundlePackageType -string "XPC!" $@/Contents/Info.plist
	plutil -replace NSExtension -json "{}" $@/Contents/Info.plist
	/usr/libexec/PlistBuddy -c 'merge $(macpin_sites)/$*/appex.share.plist :NSExtension' -c save $@/Contents/Info.plist
	-codesign -s - -f --entitlements entitlements.plist $@ && codesign -dv $@
	-asctl container acl list -file $@

install:
	cp -R $(filter %.app,$^) ~/Applications

clean:
	-cd $(appdir) && for i in $(filter %.app,$^); do rm -rf $$i; done
	-rm -rf $(outdir)

reset:
	-defaults delete $(macpin)
	-rm -rf ~/Library/Caches/$(template_bundle_id).* ~/Library/WebKit/$(macpin)
	-rm -rf ~/Library/Saved\ Application\ State/$(template_bundle_id).*
	-rm -rf ~/Library/Preferences/$(template_bundle_id).*
	-defaults read com.apple.spaces app-bindings | grep $(template_bundle_id).
	# open ~/Library/Preferences/com.apple.spaces.plist

uninstall: $(wildcard $(appnames:%=$(installdir)/%))
	rm -rf $(filter %.app,$^)

test:
	#-defaults delete $(macpin)
	($< http://browsingtest.appspot.com)

apirepl: ; ($< -i)
tabrepl: ; ($< -t)

test.app: $(appdir)/$(macpin).app
	#banner ':-}' | open -a $$PWD/$^ -f
	#-defaults delete $(template_bundle_id).$(macpin)
	#(open $^) &
	($^/Contents/MacOS/$(macpin))
# https://github.com/WebKit/webkit/blob/master/Tools/Scripts/webkitdirs.pm

# debug: $(appdir)/test.app
# http://stackoverflow.com/questions/24715891/access-a-swift-repl-in-cocoa-programs

# make SIM_ONLY=1 test.ios 
# make cross test.ios
ifeq ($(sdk),iphonesimulator)
test.ios: $(appdir)/$(macpin).app
	# npm install ios-sim -g
	ios-sim launch $< --devicetypeid "com.apple.CoreSimulator.SimDeviceType.iPhone-5, 8.3"
else
test.ios: ;
endif

# need to gen static html with https://github.com/realm/jazzy
doc: $(objs)
	for i in $(build_mods); do echo ":print_module $$i" | xcrun swift $(incdirs) -deprecated-integrated-repl; done
	#xcrun swift-ide-test -print-module -source-filename /dev/null -print-regular-comments -module-to-print Prompt
	#xcrun swift-ide-test -sdk "$(sdkpath)" -source-filename=. -print-module -module-to-print="Prompt" -synthesize-sugar-on-types -module-print-submodules -print-implicit-attrs

swiftrepl:
	# sudo /usr/sbin/DevToolsSecurity --enable
	xcrun swift $(incdirs) $(libdirs) $(linklibs) $(frameworks) -deprecated-integrated-repl

wknightly:
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

.PRECIOUS: icons/%.icns
.PHONY: clean install reset uninstall test test.app test.ios apirepl tabrepl allapps tag release wknightly doc swiftrepl
.SUFFIXES:

