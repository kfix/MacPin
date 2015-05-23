#!/usr/bin/make -rf
export
#^ export all the variables
builddir			?= build

# scan modules/ and define cross: target and vars: outdir, platform, arch, sdk, target, objs, execs, statics, incdirs, libdirs, linklibs, frameworks
include eXcode.mk

# now layout the MacPin .apps to generate
macpin				:= MacPin
macpin_sites		?= sites

template_bundle_id	:= com.github.kfix.MacPin
icondir				?= $(builddir)/icons

installdir			:= ~/Applications

appsig				:= kfix@github.com
# http://www.objc.io/issue-17/inside-code-signing.html
#`security find-identity`
# https://developer.apple.com/library/mac/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html#//apple_ref/doc/uid/TP40005929-CH4-SW13
#appsig				:= -
# ^ ad-hoc, not so great
# https://developer.apple.com/library/mac/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919-CH1-TNTAG20

appdir				?= $(outdir)/apps
appnames			= $(patsubst $(macpin_sites)/%,%.app,$(wildcard $(macpin_sites)/*))
gen_apps			= $(patsubst $(macpin_sites)/%,$(appdir)/%.app,$(wildcard $(macpin_sites)/*))
#gen_action_exts	= $(patsubst %,$(appdir)/%.appex,$(apps))
$(info Buildable MacPin apps: $(gen_apps))

ifeq ($(filter $(arch),$(archs_macosx)),)
# only intel platforms have libedit so only those execs can have terminal CLIs
$(execs): $(filter-out %/libPrompt.a, $(statics))
else
$(execs): $(statics)
endif

ifeq ($(platform),OSX)
endif
allapps install: $(gen_apps)
zip test apirepl tabrepl wknightly $(gen_apps): $(execs)
test apirepl tabrepl test.app test.ios: debug := -g -D SAFARIDBG -D DBGMENU -D APP2JSLOG -D WARN2NSLOG
wknightly: DYLD_FRAMEWORK_PATH=/Volumes/WebKit/WebKit.app/Contents/Frameworks/10.10
reinstall: allapps uninstall install
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
GH_RELEASE_JSON = '{"tag_name": "v$(VERSION)","target_commitish": "master","name": "v$(VERSION)","body": "MacPin build of version $(VERSION)","draft": false, "prerelease": true}'
#####

$(icondir)/%.xcassets: $(macpin_sites)/%/icon.png
	install -d $@
	osascript -l JavaScript iconify.jxa $(realpath $<) $(realpath $@)

$(icondir)/%.xcassets: WebKit.png
	install -d $@
	osascript -l JavaScript iconify.jxa $(realpath $<) $(realpath $@)

$(appdir): ; install -d $@

#Render plist template w/shell vars
define gen_plist_template
	install -d $(dir $@)
	EXECUTABLE_NAME=$* BUNDLE_ID=$(template_bundle_id).$* eval "echo \"$$(cat $<)\"" > $@
endef

# https://github.com/n8armstrong/lister/blob/master/Swift/Lister/Info.plist
# https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
# https://developer.apple.com/library/ios/qa/qa1686/_index.html
$(appdir)/%.app/Contents/Info.plist $(appdir)/%.app/Info.plist: templates/$(platform)/Info.plist
	$(gen_plist_template)
$(appdir)/%.app/Contents/entitlements.plist $(appdir)/%.app/entitlements.plist: templates/$(platform)/entitlements.plist
	$(gen_plist_template)

ifeq ($(platform),OSX)

$(appdir)/%.app/Contents/Resources/Icon.icns $(appdir)/%.app/Contents/Resources/Assets.car: $(icondir)/%.xcassets
	install -d $(dir $@)
	xcrun actool --output-format human-readable-text --notices --warnings --print-contents --output-partial-info-plist $@.plist \
		--platform $(sdk) --minimum-deployment-target 10.10 --target-device mac \
		--compress-pngs --compile $(dir $@) $(realpath $<)
	test -f $@

# OSX apps
# https://developer.apple.com/library/mac/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html#//apple_ref/doc/uid/10000123i-CH101-SW1
# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
# https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html
$(appdir)/%.app: $(macpin_sites)/%/* $(macpin_sites)/% $(appdir)/%.app/Contents/Info.plist $(appdir)/%.app/Contents/entitlements.plist $(appdir)/%.app/Contents/Resources/Icon.icns 
	install -d $@/Contents/MacOS $@/Contents/Frameworks $@/Contents/Resources
	$(patsubst %,cp -v % $@/Contents/MacOS/$*;,$(filter $(outdir)/exec/%,$^))
	cp -RLv $(macpin_sites)/$*/* $@/Contents/Resources/
	cp -v $(outdir)/Frameworks/*.dylib $@/Contents/Frameworks/
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $@/Contents/Info.plist
	#plutil -replace SecTaskAccess -json [] $@/Contents/Info.plist
	#plutil -replace SecTaskAccess.0 -string allowed $@/Contents/Info.plist
	[ ! -f "$(macpin_sites)/$*/Makefile" ] || $(MAKE) -C $@/Contents/Resources
	# http://pythonhosted.org//macholib/scripts.html
	python -m macholib standalone $@
	python -m macholib find $@
	codesign --verbose=4 -s $(appsig) -f --deep --ignore-resources --entitlements $@/Contents/entitlements.plist $@
	codesign --display -r- --verbose=4 --entitlements :- $@
	-spctl --verbose=4 --assess --type execute $@
	-asctl container acl list -file $@
	#xattr -w com.apple.application-instance FOOUUID $@

else ifeq ($(platform),iOS)

$(appdir)/%.app/Assets.car: $(icondir)/%.xcassets
	install -d $(dir $@)
	xcrun actool --output-format human-readable-text --notices --warnings --print-contents --output-partial-info-plist $@.plist \
		--platform $(sdk) --minimum-deployment-target 7.0  --target-device iphone  --target-device ipad --app-icon AppIcon \
		--compress-pngs --compile $(dir $@) $(realpath $<)

$(appdir)/%.app: $(macpin_sites)/% $(appdir)/%.app/entitlements.plist $(appdir)/%.app/Info.plist templates/$(platform)/LaunchScreen.xib $(icondir)/%.xcassets
	install -d $@/Frameworks
	$(patsubst %,cp -v % $@/$*;,$(filter $(outdir)/exec/%,$^))
	install_name_tool -rpath @loader_path/../Frameworks @loader_path/Frameworks $@/$*
	cp -v $(outdir)/Frameworks/*.dylib $@/Frameworks/
	cp -RLv $(macpin_sites)/$*/* $(icondir)/$*.xcassets $@/
	ibtool --compile $@/LaunchScreen.nib templates/$(platform)/LaunchScreen.xib
endif

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
	-rm -rf $(outdir) $(icondir)

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

# make cross test.ios
ifeq ($(sdk)-$(arch),iphonesimulator-x86_64)
test.ios: $(appdir)/$(macpin).app
	@xcrun simctl list | grep $(shell defaults read com.apple.iphonesimulator CurrentDeviceUDID)
	# pre-A7 devices (ipad mini 2, ipad air, iphone 5s) cannot run x86_64 builds
	# if app closes without showing launch screen, try changing the simulated device to A7 or later
	open -a "iOS Simulator.app"
	xcrun simctl getenv booted foobar || sleep 5
	xcrun simctl install booted $<
	xcrun simctl launch booted $(template_bundle_id).$(macpin) 
else
test.ios: ;
# make SIM_ONLY=1 test.ios 
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

#playground:
# need to generate an .xcworkspace with MacPin inside it as a built framework using CocoaPods::Xcodeproj
# https://guides.cocoapods.org/using/using-cocoapods.html#what-is-happening-behind-the-scenes
# then generate a .playground
# https://github.com/jas/playground

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

.PRECIOUS: $(appdir)/%.app/Info.plist $(appdir)/%.app/Contents/Info.plist $(appdir)/%.app/entitlements.plist $(appdir)/%.app/Contents/entitlements.plist $(appdir)/%.app/Contents/Resources/Icon.icns $(icondir)/%.xcassets
.PHONY: clean install reset uninstall reinstall test test.app test.ios apirepl tabrepl allapps tag release wknightly doc swiftrepl
.SUFFIXES:

