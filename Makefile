#!/usr/bin/make -rf
export
#^ export all the variables
builddir			?= build

# scan modules/ and define cross: target and vars: outdir, platform, arch, sdk, target, objs, execs, statics, incdirs, libdirs, linklibs, frameworks
archs_macosx		?= x86_64
# ^ supporting Yosemite+ only, so don't bother with 32-bit builds
archs_iphonesimulator	?= i386 x86_64

archs_iphoneos		?= arm64
target_ver_OSX		?= 10.11
target_ver_iOS		?= 9.1

include eXcode.mk

# now layout the MacPin .apps to generate
macpin				:= MacPin
macpin_sites		?= sites

template_bundle_id	:= com.github.kfix.MacPin
xcassets			:= $(builddir)/xcassets/$(platform)
icontypes			:= imageset

ifeq ($(platform),OSX)
icontypes			+= iconset
else
icontypes			+= appiconset
endif

installdir			:= ~/Applications/MacPin.localized

#appsig				?= kfix@github.com
# http://www.objc.io/issue-17/inside-code-signing.html
#`security find-identity`
# https://developer.apple.com/library/mac/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html#//apple_ref/doc/uid/TP40005929-CH4-SW13
appsig_iOS			:= iPhone Developer
#appsig_OSX			:= Mac Developer
appsig				?= -
# ^ ad-hoc, not so great
# https://developer.apple.com/library/mac/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919-CH1-TNTAG20

# https://developer.apple.com/library/ios/technotes/tn2415/_index.html
mobileprov_team_id := HKFYQ3A8TC

bundle_untracked	?= 0
appdir				:= $(outdir)/apps
appnames			= $(patsubst $(macpin_sites)/%,%.app,$(wildcard $(macpin_sites)/*))
gen_apps			= $(patsubst $(macpin_sites)/%,$(appdir)/%.app,$(wildcard $(macpin_sites)/*))
#gen_action_exts	= $(patsubst %,$(appdir)/%.appex,$(apps))
$(info Buildable MacPin apps:)
$(foreach app,$(gen_apps), $(info $(app)) )

ifeq (,$(filter $(arch),$(archs_macosx)))
# only intel platforms have libedit so only those execs can have terminal CLIs
$(execs): $(filter-out $(outdir)/obj/libPrompt.a %/libPrompt.a %/libPrompt.o %/libPrompt.dylib, $(statics))
$(info $(filter-out $(outdir)/obj/libPrompt.a %/libPrompt.a %/libPrompt.o %/libPrompt.dylib, $(statics)))
$(execs): $(statics)
else
# use static libs, not dylibs to build all executable modules
$(execs): $(statics)
endif

ifeq ($(platform),OSX)
endif
allapps install: $(gen_apps)
zip test apirepl tabrepl wknightly stp $(gen_apps): $(execs)
test apirepl tabrepl test.app test.ios stp stp.app: debug := -g -D SAFARIDBG -D DEBUG -D DBGMENU -D APP2JSLOG -D WK2LOG
stp stp.app: linkopts_main += -Wl,-dyld_env,DYLD_FRAMEWORK_PATH="/Applications/Safari Technology Preview.app/Contents/Frameworks"
stp stp.app: debug += -D STP
stp stp.app: clang += -DSTP
stp stp.app: swiftc += -Xcc -DSTP
test apirepl tabrepl test.app test.ios stp stp.app: | $(execs:%=%.dSYM)

ifeq (iphonesimulator, $(sdk))
codesign :=
else ifneq (,$(appsig_$(platform)))
appsig	:= $(appsig_$(platform))
codesign := yes
else ifeq ($(appsig),-)
codesign := yes
else ifneq ($(appsig),)
test test.app stp stp.app release: appsig := -
endif

reinstall: allapps uninstall install
noop: ;
#allow these targets to pull in all files in sites/*/
%.app install: bundle_untracked := 1

ifeq (0,$(MAKELEVEL))
# parent make invocation
else
#submake
endif

# github settings for release: target
#####
VERSION		 := 1.5.0
LAST_TAG	 != git describe --abbrev=0 --tags
USER		 := kfix
REPO		 := MacPin
ZIP			 := $(realpath $(outdir))/$(REPO)-$(platform)-$(arch).zip
GH_RELEASE_JSON = '{"tag_name": "v$(VERSION)","target_commitish": "master","name": "v$(VERSION)","body": "MacPin $(plaform) $(arch) build of version $(VERSION)","draft": false, "prerelease": true}'
#####

$(xcassets)/%.xcassets: $(macpin_sites)/%/icon.png
	osascript -l JavaScript iconify.jxa $< $@ $(icontypes)

$(xcassets)/%.xcassets: templates/xcassets/$(platform)/%/*.png
	for i in $^; do osascript -l JavaScript iconify.jxa $$i $@ imageset; done

$(xcassets)/%.xcassets: templates/xcassets/%/*.png
	for i in $^; do osascript -l JavaScript iconify.jxa $$i $@ imageset; done

#$(appdir): ; install -d $@

#Render plist template w/shell vars
# https://developer.apple.com/library/ios/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/1-Build_Setting_Reference/build_setting_ref.html
define gen_plist_template
	install -d $(dir $@)
	EXECUTABLE_NAME=$* BUNDLE_ID=$(template_bundle_id).$* PROV_ID=$(mobileprov_team_id) PLAT_VER=$(target_ver_$(platform)) eval "echo \"$$(cat $<)\"" > $@
endef

# https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
# https://developer.apple.com/library/ios/qa/qa1686/_index.html
$(appdir)/%.app/Contents/Info.plist $(appdir)/%.app/Info.plist: templates/$(platform)/Info.plist
	$(gen_plist_template)

$(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings $(appdir)/%.app/en.lproj/InfoPlist.strings: templates/$(platform)/InfoPlist.strings
	$(gen_plist_template)

# https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/SystemExtensionKeys.html#//apple_ref/doc/uid/TP40014212-SW17
$(appdir)/%/Contents/PlugIns/ActionExtension.appex/Contents/Info.plist $(appdir)/%.appex/Info.plist: templates/appex/$(platform)/Info.plist
		$(gen_plist_template)

# https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html
$(outdir)/%.entitlements.plist: templates/$(platform)/entitlements.plist
	$(gen_plist_template)

# phony targets for cmdline convenience
%.app: $(appdir)/%.app
sites/%: $(appdir)/%.app
	@echo Finished building $<
#modules/%: $(outdir)/obj/%.o

ifeq ($(platform),OSX)

%.scpt: %.jxa
	osacompile -l JavaScript -o "$@" "$<"

$(appdir)/%.app/Contents/Resources/Icon.icns $(appdir)/%.app/Contents/Resources/Assets.car: $(xcassets)/%.xcassets
	@install -d $(dir $@)
	xcrun actool --output-format human-readable-text --notices --warnings --print-contents --output-partial-info-plist $@.plist \
		--platform $(sdk) --minimum-deployment-target $(target_ver_OSX) --target-device mac \
		--compress-pngs --compile $(dir $@) $(realpath $<)
	test -f $@

# OSX apps
# https://developer.apple.com/library/mac/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html#//apple_ref/doc/uid/10000123i-CH101-SW1
# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html

$(appdir)/%.app: $(macpin_sites)/% $(macpin_sites)/%/* $(appdir)/%.app/Contents/Info.plist $(outdir)/%.entitlements.plist $(appdir)/%.app/Contents/Resources/Icon.icns templates/Resources/ $(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings
	@install -d $@ $@/Contents/MacOS $@/Contents/Resources
	$(patsubst %,cp % $@/Contents/MacOS/$*;,$(filter $(outdir)/exec/%,$^))
	#[ -z "$(debug)" ] || $(patsubst %,cp -RL % $@/Contents/MacOS/$*.dSYM,$(filter $(outdir)/exec/%.dSYM,$^))
	cp -RL templates/Resources $@/Contents
	#git ls-files -zc $(bundle_untracked) $(macpin_sites)/$* | xargs -0 -J % install -DT % $@/Contents/Resources/
	(($(bundle_untracked))) || git archive HEAD $(macpin_sites)/$*/ | tar -xv --strip-components 2 -C $@/Contents/Resources
	(($(bundle_untracked))) && cp -RL $(macpin_sites)/$*/* $@/Contents/Resources/ || true
	[ ! -d $@/Contents/Resources/Library ] || ln -sfh Resources/Library $@/Contents/Library
	[ ! -n "$(wildcard $(outdir)/Frameworks/*.dylib)" ] || cp -a $(outdir)/Frameworks $@/Contents
	[ ! -n "$(wildcard $(outdir)/SwiftSupport/*.dylib)" ] || cp -a $(outdir)/SwiftSupport $@/Contents
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $@/Contents/Info.plist
	[ ! -f "$(macpin_sites)/$*/Makefile" ] || $(MAKE) -C $@/Contents/Resources
	[ ! -n "$(codesign)" ] || codesign --verbose=4 -s '$(appsig)' -f --deep --ignore-resources --strict --entitlements $(outdir)/$*.entitlements.plist $@ $@/Contents/SwiftSupport/*.dylib
	-codesign --display -r- --verbose=4 --deep --entitlements :- $@
	-spctl -vvvv --raw --assess --type execute $@
	-asctl container acl list -file $@
	@touch $@
#xattr -w com.apple.application-instance $(shell echo uuidgen) $@

else ifeq ($(platform),iOS)

$(appdir)/%.app/Assets.car: $(xcassets)/%.xcassets $(xcassets)/icons8.xcassets
	@install -d $(dir $@)
	xcrun actool --output-format human-readable-text --notices --warnings --print-contents --output-partial-info-plist $@.plist \
		--platform $(sdk) --minimum-deployment-target $(target_ver_iOS)  --target-device iphone  --target-device ipad --app-icon AppIcon \
		--compress-pngs --compile $(dir $@) $(realpath $(filter %.xcassets, $^))
	test -f $@

$(appdir)/%.app/LaunchScreen.nib: templates/$(platform)/LaunchScreen.xib
	@install -d $(dir $@)
	ibtool --compile $@ $<

$(appdir)/%.app: $(macpin_sites)/% $(macpin_sites)/%/* $(outdir)/%.entitlements.plist $(appdir)/%.app/Info.plist templates/$(platform)/LaunchScreen.xib $(appdir)/%.app/LaunchScreen.nib $(appdir)/%.app/Assets.car templates/Resources templates/Resources/* $(appdir)/%.app/en.lproj/InfoPlist.strings
	@install -d $@ $@/Frameworks
	@install -d $@ $@/SwiftSupport
	$(patsubst %,cp % $@/$*;,$(filter $(outdir)/exec/%,$^))
	#[ -z "$(debug)" ] || $(patsubst %,cp -RL % $@/$*.dSYM;,$(filter $(outdir)/exec/%.dSYM,$^))
	install_name_tool -rpath @loader_path/../Frameworks @loader_path/Frameworks $@/$*
	install_name_tool -rpath @loader_path/../SwiftSupport @loader_path/SwiftSupport $@/$*
	[ ! -n "$(wildcard $(outdir)/Frameworks/*.dylib)" ] || cp -a $(outdir)/Frameworks $@/
	[ ! -n "$(wildcard $(outdir)/SwiftSupport/*.dylib)" ] || cp -a $(outdir)/SwiftSupport $@/
	rsync -av --exclude='Library/' $(macpin_sites)/$*/ $@
	[ ! -n "$(codesign)" ] || codesign --verbose=4 -s '$(appsig)' -f --deep --ignore-resources --strict --entitlements $(outdir)/$*.entitlements.plist $@ $@/SwiftSupport/*.dylib
	-codesign --display -r- --verbose=4 --deep --entitlements :- $@
	-spctl -vvvv --raw --assess --type execute $@
	-asctl container acl list -file $@
	@touch $@
endif

# http://www.appcoda.com/ios-8-action-extensions-tutorial/
$(appdir)/%/PlugIns/ActionExtension.appex: $(appdir)/%/PlugIns/ActionExtension.appex/Info.plist $(icons)/%.icns $(macpin_sites)/%/appex.js
	# ld -e _NSExtensionMain -fapplicationextension -o execs/MacPin.appex obj/ActionExtension.o
	#  http://bazel.io/docs/be/objective-c.html#ios_extension
	#/usr/libexec/PlistBuddy -c 'merge $(macpin_sites)/$*/appex.share.plist :NSExtension' -c save $@/Contents/Info.plist
	#-codesign -s - -f --entitlements entitlements.plist $@ && codesign -dv $@
	#-asctl container acl list -file $@

ifeq ($(sdk),iphonesimulator)
install:
	open -a "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
	xcrun simctl getenv booted foobar || sleep 5
	@xcrun simctl list | grep $(shell defaults read com.apple.iphonesimulator CurrentDeviceUDID)
	# pre-A7 devices (ipad mini 2, ipad air, iphone 5s) cannot run x86_64 builds
	# if app closes without showing launch screen, try changing the simulated device to A7 or later
	for i in $(filter %.app,$^); do xcrun simctl install booted $$i; done
else ifeq ($(sdk),iphoneos)
install: /usr/local/bin/ios-deploy
	for i in $(filter %.app,$^); do ios-deploy -b $$i; done
else
install:
	install -d $(installdir)
	cp -R $(filter %.app,$^) $(installdir)
endif

unregister:
	-/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u $(builddir)/*/apps/*.app

clean: unregister
	-rm -rf $(outdir) $(xcassets)

binclean:
	rm -f $(execs) $(objs) $(statics) $(dynamics) $(outdir)/obj/*.o

cached:
	-find ~/Library/Caches/$(template_bundle_id).$(APP)* ~/Library/WebKit/$(template_bundle_id).$(APP)*

reset:
	-defaults delete $(macpin)
	-rm -rfv ~/Library/Caches/$(template_bundle_id).$(APP)* ~/Library/WebKit/$(macpin) ~/Library/WebKit/$(template_bundle_id).$(APP)*
	-rm -rfv ~/Library/Saved\ Application\ State/$(template_bundle_id).$(APP)*
	-rm -rfv ~/Library/Preferences/$(template_bundle_id).$(APP)*
	-defaults read com.apple.spaces app-bindings | grep $(template_bundle_id).$(APP)
	# open ~/Library/Preferences/com.apple.spaces.plist

uninstall: $(wildcard $(appnames:%=$(installdir)/%))
	rm -rf $(filter %.app,$^)

stp test:
	#-defaults delete $(macpin)
	($< -i http://browsingtest.appspot.com)

apirepl: ; ($< -i)
tabrepl: ; ($< -t)

stp.app test.app: $(appdir)/$(macpin).app
	#banner ':-}' | open -a $$PWD/$^ -f
	#-defaults delete $(template_bundle_id).$(macpin)
	#(open $^) &
	($^/Contents/MacOS/$(macpin) -i)
# https://github.com/WebKit/webkit/blob/master/Tools/Scripts/webkitdirs.pm

# debug: $(appdir)/test.app
# http://stackoverflow.com/questions/24715891/access-a-swift-repl-in-cocoa-programs

# make cross test.ios
# .crash: https://developer.apple.com/library/ios/technotes/tn2151/_index.html
# & https://developer.apple.com/library/ios/qa/qa1747/_index.html
# https://github.com/rpetrich/deviceconsole
/usr/local/bin/ios-sim: ; npm -g install ios-sim
/usr/local/bin/ios-deploy: ; npm -g install ios-deploy
ifeq ($(sdk),iphonesimulator)
test.ios: $(appdir)/$(macpin).app
	plutil -convert binary1 $</Info.plist
	open -a "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
	xcrun simctl getenv booted foobar || sleep 5
	@xcrun simctl list | grep $(shell defaults read com.apple.iphonesimulator CurrentDeviceUDID)
	# pre-A7 devices (ipad mini 2, ipad air, iphone 5s) cannot run x86_64 builds
	# if app closes without showing launch screen, try changing the simulated device to A7 or later
	-xcrun simctl install booted $<; xcrun simctl launch booted $(template_bundle_id).$(macpin) true
	-tail -n100 ~/Library/Logs/CoreSimulator/$(shell defaults read com.apple.iphonesimulator CurrentDeviceUDID)/system.log
	-@for i in ~/Library/Logs/DiagnosticReports/$(macpin)_$(shell date +%Y-%m-%d-%H%M)*_$(shell scutil --get LocalHostName).crash; do [ -f $$i ] && cat $$i && echo $$i; break; done
else ifeq ($(sdk),iphoneos)
test.ios: $(appdir)/$(macpin).app /usr/local/bin/ios-deploy
	ios-deploy -d -b $<
else
test.ios: ;
# make only=sim test.ios
endif

# need to gen static html with https://github.com/realm/jazzy
doc: $(execs) $(objs)
	for i in $(build_mods) WebKit WebKitPrivates; do echo ":print_module $$i" | xcrun swift $(incdirs) -deprecated-integrated-repl; done
	#xcrun swift-ide-test -print-module -source-filename /dev/null -print-regular-comments -module-to-print Prompt
	#xcrun swift-ide-test -sdk "$(sdkpath)" -source-filename=. -print-module -module-to-print="Prompt" -synthesize-sugar-on-types -module-print-submodules -print-implicit-attrs

swiftrepl:
	# sudo /usr/sbin/DevToolsSecurity --enable
	xcrun swift $(incdirs) $(libdirs) $(linklibs) $(frameworks) -deprecated-integrated-repl

#.safariextz: http://developer.streak.com/2013/01/how-to-build-safari-extension-using.html

#playground:
# need to generate an .xcworkspace with MacPin inside it as a built framework using CocoaPods::Xcodeproj
# https://guides.cocoapods.org/using/using-cocoapods.html#what-is-happening-behind-the-scenes
# then generate a .playground
# https://github.com/jas/playground

tag:
	git tag -f -a v$(VERSION) -m 'release $(VERSION)'

zip: $(ZIP)
$(ZIP): .zipignore
	[ ! -f $(ZIP) ] || rm $(ZIP)
	zip -r $@ extras/*.workflow --exclude @extras/.zipignore
	cd $(appdir) && zip -g -ws -r $@ *.app --exclude @$(realpath $+)

testrelease: clean tag allapps $(ZIP)
ifneq ($(GITHUB_ACCESS_TOKEN),)
release: clean tag allapps $(ZIP) upload
upload:
	git push -f --tags
	posturl=$$(curl --data $(GH_RELEASE_JSON) "https://api.github.com/repos/$(USER)/$(REPO)/releases?access_token=$(GITHUB_ACCESS_TOKEN)" | jq -r .upload_url | sed 's/[\{\}]//g') && \
	dload=$$(curl --fail -X POST -H "Content-Type: application/gzip" --data-binary "@$(ZIP)" "$$posturl=$(notdir $(ZIP))&access_token=$(GITHUB_ACCESS_TOKEN)" | jq -r .browser_download_url | sed 's/[\{\}]//g') && \
	echo "$(REPO) now available for download at $$dload"
else
release:
	@echo You need to export \$$GITHUB_ACCESS_TOKEN to make a release!
	@exit 1
endif

.PRECIOUS: $(appdir)/%.app/Info.plist $(appdir)/%.app/Contents/Info.plist $(appdir)/%.app/entitlements.plist $(appdir)/%.app/Contents/entitlements.plist $(appdir)/%.app/Contents/Resources/Icon.icns $(xcassets)/%.xcassets $(appdir)/%.app/Assets.car $(appdir)/%.app/LaunchScreen.nib $(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings $(appdir)/%.app/en.lproj/InfoPlist.strings $(outdir)/%.entitlements.plist
.PHONY: clean install reset uninstall reinstall test test.app test.ios stp stp.app apirepl tabrepl allapps tag release doc swiftrepl %.app zip $(ZIP) upload sites/% modules/% testrelease submake_% statics dynamics
.SUFFIXES:
