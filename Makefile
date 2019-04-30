#!/usr/bin/make -rf
export
#^ export all the variables
builddir			?= build

VERSION				:= 2019.5.0

# 1 == use STP.app's WebKit if its present at runtime
STP 				?= 1
# https://github.com/Homebrew/homebrew-cask-versions/commits/master/Casks/safari-technology-preview.rb
# https://webkit.org/build-archives/

SWFTFLAGS			?= -suppress-warnings
SWCCFLAGS			?= -Wno-unreachable-code

# scan modules/ and define cross: target and vars: outdir, platform, arch, sdk, target, objs, execs, statics, incdirs, libdirs, linklibs, frameworks
archs_macosx		?= x86_64
# ^ supporting Yosemite+ only, so don't bother with 32-bit builds
archs_iphonesimulator	?= x86_64

archs_iphoneos		?= arm64
target_ver_OSX		?= 10.11
target_ver_iOS		?= 9

xcode				?= /Applications/Xcode.app
swifttoolchain		?= XcodeDefault
swiftver			?= 4.2
nextswiftver		?= 5

ifneq ($(xcode),)
xcrun				?= env DEVELOPER_DIR=$(xcode)/Contents/Developer xcrun
xcs					?= env DEVELOPER_DIR=$(xcode)/Contents/Developer xcode-select
endif

macpin				:= MacPin
macpin_sites		?= sites
installdir			:= ~/Applications/MacPin.localized
bundle_untracked	?= 0
appnames			= $(patsubst $(macpin_sites)/%,%.app,$(wildcard $(macpin_sites)/*))

usage help:
	@printf '\nusage:\tmake (V=1) <target>\n\ntargets:\n%s'
	@printf '\t%s\n' reinstall uninstall test test.app stpdoc sites/*

include eXcode.mk
mk := $(firstword $(MAKEFILE_LIST))
$(info )
$(info [$(mk)])
$(info )

# print webkit.framework version?

appdir				:= $(outdir)/apps

# now layout the MacPin .app targets to generate based on eXcode's build targets
$(info $(macpin_sites)/* => $(appdir) => $(installdir)/*.app)

gen_apps			= $(patsubst $(macpin_sites)/%,$(appdir)/%.app,$(wildcard $(macpin_sites)/*))
#gen_action_exts	= $(patsubst %,$(appdir)/%.appex,$(apps))

template_bundle_id	:= com.github.kfix.MacPin
xcassets			:= $(builddir)/xcassets/$(platform)
icontypes			:= imageset

ifeq ($(platform),OSX)
icontypes			+= iconset
else
icontypes			+= appiconset
endif


# http://www.objc.io/issue-17/inside-code-signing.html
# https://developer.apple.com/library/mac/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html#//apple_ref/doc/uid/TP40005929-CH4-SW13
# https://developer.apple.com/library/mac/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919-CH1-TNTAG20

# create this file if you want to test dev-signed iOS apps on your own devices
-include apple_dev_id.mk
appsig				?= -
# ^ ad-hoc, not so great
#appsig_OSX			:= Mac Developer
appsig_iOS			:= iPhone Developer
# open Xcode -> Preferences -> Accounts -> +Add: Apple ID -> Manage Certificates -> +Add: iOS Development
#  `security find-identity` will then show your Developer keys you can use for appsig*:
mobileprov_team_id	?=
# https://developer.apple.com/account/#/membership/ "Team ID"


ifeq (,$(filter $(arch),$(archs_macosx)))
# only intel platforms have libedit so only those execs can have terminal CLIs
$(lexecs): $(filter-out $(outdir)/obj/libPrompt.a %/libPrompt.a %/libPrompt.o %/libPrompt.dylib, $(statics))
$(info $(filter-out $(outdir)/obj/libPrompt.a %/libPrompt.a %/libPrompt.o %/libPrompt.dylib, $(statics)))
else
endif

# use static libs, not dylibs to build all executable modules
#$(execs): $(statics)

# make a jumbo framework and its stub launcher
#
#jumbolib := $(firstword $(filter %/lib$(macpin).dylib, $(dynamics)))
jumbolib := $(outdir)/Frameworks/$(macpin).framework
# need SharedFramework https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Tasks/InstallingFrameworks.html
jumbodeps := $(filter-out %/lib$(macpin).a, $(statics))
$(jumbolib): linklibs := $(patsubst lib%.a,-l%, $(notdir $(jumbodeps)))
#jumbodeps := $(filter-out %/$(macpin).o, $(objs))
#$(jumbolib): linklibs := $(patsubst %, -Xlinker -l%, $(notdir $(jumbodeps)))
#$(jumbolib): extrainputs := $(jumbodeps)
jumbody := $(firstword $(filter %/lib$(macpin).dylib, $(dynamics)))
$(jumbody): $(jumbodeps)
$(jumbolib): $(jumbody)
$(lexecs): $(jumbolib)
#$(lexecs): linklibs := -l$(macpin)
$(info Jumbo-execs: $(lexecs))
$(info Jumbo-deps: $(jumbodeps))
$(info Jumbo-lib: $(jumbolib))

allicons: $(patsubst %,%/Contents/Resources/Icon.icns,$(gen_apps))
allapps install: $(gen_apps)

ifeq ($(platform)$(osswiftlibdir),OSX)
# need to vendor SwiftSupport from the SDK, because this host OS doesn't come with them
swiftsupport := $(outdir)/SwiftSupport
else
swiftsupport :=
endif

zip test apirepl tabrepl wknightly stp $(gen_apps): $(lexecs) $(swiftsupport)
doc test apirepl tabrepl test.app test.ios dbg dbg.app stp stp.app test_% $(appnames:%=test_%): debug := -g -D SAFARIDBG -D DEBUG -D DBGMENU -D APP2JSLOG
#-D WK2LOG

# older OSX/macOS with backported Safari.app have vendored WK/JSC frameworks
rpath					:= /System/Library/StagedFrameworks/Safari

ifeq ($(STP),1)
stpdir					:= /Applications/Safari\ Technology\ Preview.app
stpframes				:= $(wildcard $(stpdir)/Contents/Frameworks)
ifneq ($(stpframes),)
webkitdir				:= $(stpframes)/WebKit.framework
safaridir				:= $(wildcard $(stpdir))

# FIXME: only release builds should have STP burned into the RPATH
#rpath					+= :$(stpframes)

# man dyld
env += DYLD_VERSIONED_FRAMEWORK_PATH="$(stpframes)"
endif
endif
env += DYLD_PRINT_LIBRARIES=1

linkopts_main 			:= -Wl,-dyld_env,DYLD_VERSIONED_FRAMEWORK_PATH="$(rpath)"

webkitdir				?= /System/Library/Frameworks/WebKit.framework
jscdir					?= /System/Library/Frameworks/JavaScriptCore.framework
safaridir				?= /Applications/Safari.app

safariver				:= $(shell defaults read "$(safaridir)/Contents/Info" CFBundleShortVersionString)
webkitver				:= $(shell defaults read "$(webkitdir)/Resources/Info" CFBundleVersion)
$(info $(safaridir) => $(safariver))
$(info $(webkitdir) => $(webkitver))

test apirepl tabrepl test.app dbg dbg.app test.ios stp stp.app: | $(lexecs:%=%.dSYM)

ifeq (iphonesimulator, $(sdk))
codesign :=
else ifneq (,$(appsig_$(platform)))
appsig	:= $(appsig_$(platform))
codesign := yes
else ifeq ($(appsig),-)
# Note: the ad-hoc signature (-) is only good for testing sandboxing on the builder's machine
#  ( & sandboxing is required for -DSAFARIDBG to work )
# for distribution, should use a self-signed signature or none at all (no codesign= var)
codesign := yes
else ifneq ($(appsig),)
codesign := yes
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
LAST_TAG	 != git describe --abbrev=0 --tags
USER		 := kfix
REPO		 := MacPin
ZIP			 := $(realpath $(outdir))/$(REPO)-$(platform)-$(arch)-$(VERSION).zip
TXZ			 := $(realpath $(outdir))/$(REPO)-$(platform)-$(arch)-$(VERSION).tar.xz
DMG			 := $(realpath $(outdir))/$(REPO)-$(platform)-$(arch)-$(VERSION).dmg
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
# https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html#//apple_ref/doc/uid/20000852-CHDJDFIC
$(appdir)/%.app/Contents/Info.plist $(appdir)/%.app/Info.plist: templates/$(platform)/Info.plist
	$(gen_plist_template)
ifeq ($(platform),OSX)
	[ ! -f $(macpin_sites)/$*/ServicesOSX.plist ] || /usr/libexec/PlistBuddy -c 'merge $(macpin_sites)/$*/ServicesOSX.plist :NSServices' -c save $@
endif

$(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings $(appdir)/%.app/en.lproj/InfoPlist.strings: templates/$(platform)/InfoPlist.strings
	$(gen_plist_template)

# https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/SystemExtensionKeys.html#//apple_ref/doc/uid/TP40014212-SW17
$(appdir)/%/Contents/PlugIns/ActionExtension.appex/Contents/Info.plist $(appdir)/%.appex/Info.plist: templates/appex/$(platform)/Info.plist
		$(gen_plist_template)

# https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html
$(outdir)/%.entitlements.plist: templates/$(platform)/entitlements.plist
	$(gen_plist_template)

# phony targets for cmdline convenience
%.dSYM: $(appdir)/%.dSYM
sites/% %.app: $(appdir)/%.app
	@echo Finished building $<
#modules/%: $(outdir)/obj/%.o

test_%: $(appdir)/%.app | $(appdir)/MacPin.app
	-/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -v $(outdir)/apps/ -apps com.github.kfix.MacPin.MacPin
	($(env) $^/Contents/MacOS/$(basename $(notdir $^)) -i) #|| { echo $$?; [ -t 1 ] && stty sane; }

ifeq ($(platform),OSX)

%.scpt: %.jxa
	osacompile -l JavaScript -o "$@" "$<"

$(appdir)/%.app/Contents/Resources/Icon.icns $(appdir)/%.app/Contents/Resources/Assets.car: $(xcassets)/%.xcassets
	@install -d $(dir $@)
	xcrun actool --output-format human-readable-text --notices --warnings --print-contents --output-partial-info-plist $@.plist \
		--platform $(sdk) --minimum-deployment-target 10.12 --target-device mac \
		--compress-pngs --compile $(dir $@) $(realpath $(filter %.xcassets, $^)) >/dev/null
	test -f $@ || { echo "error: $@ was not created by actool!" && cat $@.plist && exit 1; }
	# | grep '/* com.apple.actool.compilation-results */\n\w+ Icon.icns'

# OSX apps
# https://developer.apple.com/library/mac/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html#//apple_ref/doc/uid/10000123i-CH101-SW1
# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html

# https://lldb.llvm.org/symbols.html https://blog.vucica.net/2013/01/symbolicating-mac-apps-crash-reports-manually.html
# https://blog.bugsnag.com/symbolicating-ios-crashes/ https://www.cnblogs.com/feng9exe/p/7978040.html
$(appdir)/%.dSYM:
	@install -d $@ $@/Contents/Resources/DWARF
	$(patsubst %,cp -f % $@/Contents/Resources/DWARF/$*,$(filter $(outdir)/lexec/%.dSYM/Contents/Resources/DWARF/%,$^))

$(outdir)/Frameworks/%.framework/Versions/A/Resources/Info-macOS.plist: templates/framework/Info-macOS.plist
	$(gen_plist_template)

# build the umbrella framework bundle
# https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/FrameworkAnatomy.html
# https://developer.apple.com/library/archive/technotes/tn2435/_index.html#//apple_ref/doc/uid/DTS40017543-CH1-EMBED_SECTION
# https://www.bignerdranch.com/blog/it-looks-like-you-are-trying-to-use-a-framework/
$(outdir)/Frameworks/%.framework/Versions/A/Frameworks:
	@install -d $@
	# if SwiftSupport is needed, the rpath of the Frameworks/*.dylib should point to it and stdlib tool will find it
	[ ! -z "$(codesign)" ] || $(swift-stdlibtool) --copy --verbose --scan-folder $(outdir)/Frameworks --destination $@
	[ ! -n "$(codesign)" ] || $(swift-stdlibtool) --copy --verbose --sign $(appsig) --scan-folder $(outdir)/Frameworks --destination $@
	@touch $@

$(outdir)/Frameworks/%.framework: $(outdir)/obj/lib%.dylib $(outdir)/Frameworks/%.framework/Versions/A/Frameworks $(outdir)/Frameworks/%.framework/Versions/A/Resources/Info-macOS.plist 
	@install -dv $@
	@rm -fv $@/Versions/Current $@/Resources $@/Frameworks %@/$*
	@ln -sf A $@/Versions/Current
	@ln -sf Versions/Current/$* $@/$*
	@ln -sf Versions/Current/Resources $@/Resources
	@ln -sf Versions/Current/Frameworks $@/Frameworks
	$(patsubst %,cp -RL % $@/Versions/A/$*,$(filter %.dylib,$^))
	$(patsubst %,cp -RL % $@/Versions/A/$*.dSYM,$(filter %.dSYM,$^))
	# need a Resources/Info-macos.plist & version.plist
	-[ ! -n "$(codesign)" ] || codesign --verbose=4 -s '$(appsig)' -f --deep --ignore-resources --strict --entitlements $(outdir)/$*.entitlements.plist $@

#build the app bundle
$(appdir)/%.app: $(macpin_sites)/% $(macpin_sites)/%/* $(appdir)/%.app/Contents/Info.plist $(outdir)/%.entitlements.plist $(appdir)/%.app/Contents/Resources/Icon.icns templates/Resources/ $(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings $(outdir)/lexec/$(macpin)
	@install -d $@ $@/Contents/MacOS $@/Contents/Resources
	$(patsubst %,COMMAND_MODE=legacy cp -f % $@/Contents/MacOS/$*;,$(filter $(outdir)/lexec/%,$^))
	#[ -z "$(debug)" ] || $(patsubst %,cp -RL % $@/Contents/MacOS/$*.dSYM,$(filter $(outdir)/exec/%.dSYM,$^))
	COMMAND_MODE=legacy cp -fRL templates/Resources $@/Contents
	#git ls-files -zc $(bundle_untracked) $(macpin_sites)/$* | xargs -0 -J % install -DT % $@/Contents/Resources/
	(($(bundle_untracked))) || git archive HEAD $(macpin_sites)/$*/ | tar -xv --strip-components 2 -C $@/Contents/Resources
	(($(bundle_untracked))) && COMMAND_MODE=legacy cp -fRL $(macpin_sites)/$*/* $@/Contents/Resources/ || true
	[ ! -d $@/Contents/Resources/Library ] || ln -sfh Resources/Library $@/Contents/Library
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $@/Contents/Info.plist >/dev/null
	[ ! -f "$(macpin_sites)/$*/Makefile" ] || $(MAKE) -C $@/Contents/Resources
	[ ! -n "$(codesign)" ] || codesign --verbose=4 -s '$(appsig)' -f --deep --ignore-resources --strict --entitlements $(outdir)/$*.entitlements.plist $@
	-codesign --display -r- --verbose=4 --deep --entitlements :- $@
	-spctl -vvvv --assess --type execute $@ # App Store-ability
	-asctl container acl list -file $@
	[ ! -n "$(codesign)" ] || codesign --verbose=4 --deep --verify --strict $@
	-[ ! -z "$(codesign)" ] || codesign --verbose=4 --remove-signature $@
	@touch $@
#xattr -w com.apple.application-instance $(shell echo uuidgen) $@

# the main macpin app contains the core framework
$(appdir)/$(macpin).app/Contents/Frameworks: $(jumbolib)
	rm -rfv $@
	@install -dv $@
	$(patsubst %,cp -R % $@/,$(filter %.framework,$^))

$(appdir)/$(macpin).app: $(appdir)/$(macpin).app/Contents/Frameworks

else ifeq ($(platform),iOS)

$(appdir)/%.app/Assets.car: $(xcassets)/%.xcassets $(xcassets)/icons8.xcassets
	@install -d $(dir $@)
	xcrun actool --output-format human-readable-text --notices --warnings --print-contents --output-partial-info-plist $@.plist \
		--platform $(sdk) --minimum-deployment-target $(target_ver_iOS)  --target-device iphone  --target-device ipad --app-icon AppIcon \
		--compress-pngs --compile $(dir $@) $(realpath $(filter %.xcassets, $^)) > /dev/null
	test -f $@ || { echo "error: $@ was not created by actool!" && cat $@.plist && exit 1; }

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
	#[ ! -n "$(codesign)" ] || codesign --verbose=4 -s '$(appsig)' -f --deep --ignore-resources --strict --entitlements $(outdir)/$*.entitlements.plist $@ $@/SwiftSupport/*.dylib
	#-codesign --display -r- --verbose=4 --deep --entitlements :- $@
	-codesign --display $@
	#-spctl -vvvv --raw --assess --type execute $@
	#-asctl container acl list -file $@
	@touch $@
endif

# https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/SafariAppExtension_PG/index.html#//apple_ref/doc/uid/TP40017319
# http://www.appcoda.com/ios-8-action-extensions-tutorial/
$(appdir)/%/PlugIns/ActionExtension.appex: $(appdir)/%/PlugIns/ActionExtension.appex/Info.plist $(icons)/%.icns $(macpin_sites)/%/appex.js
	# ld -e _NSExtensionMain -fapplicationextension -o execs/MacPin.appex obj/ActionExtension.o
	#  http://bazel.io/docs/be/objective-c.html#ios_extension
	#/usr/libexec/PlistBuddy -c 'merge $(macpin_sites)/$*/appex.share.plist :NSExtension' -c save $@/Contents/Info.plist
	#-codesign -s - -f --entitlements entitlements.plist $@ && codesign -dv $@
	#-asctl container acl list -file $@

# https://developer.apple.com/documentation/networkextension/neappproxyprovider
$(appdir)/%/PlugIns/AppProxy.appex: $(appdir)/%/PlugIns/AppProxy.appex/Info.plist $(icons)/%.icns

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
	for a in $(filter %.app,$^); do echo inst $$a; cp -R $$a $(installdir); sleep 0.5; done
endif
# /System/Library/CoreServices/pbs # look for new NSServices

unregister:
	-/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u $(builddir)/*/apps/*.app

clean: unregister
	-rm -rf $(outdir) $(xcassets)

binclean:
	rm -f $(lexecs) $(objs) $(statics) $(dynamics) $(outdir)/obj/*.o
	rm -rf $(outdir)/SwiftSupport $(outdir)/Frameworks

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
	for a in $(filter %.app,$^); do echo del $$a; rm -rf $$a; done

stp test: $(appdir)/$(macpin).app
	#-defaults delete $(macpin)
	($(env) $< -i http://browsingtest.appspot.com) #|| { echo $$?; [ -t 1 ] && stty sane; }

apirepl: ; ($< -i)
tabrepl: ; ($< -t)

stp.app test.app: $(appdir)/$(macpin).app
	#banner ':-}' | open -a $$PWD/$^ -f
	#-defaults delete $(template_bundle_id).$(macpin)
	#(open $^) &
	($(env) $^/Contents/MacOS/$(macpin) -i) #|| { echo $$?; [ -t 1 ] && stty sane; }
# https://github.com/WebKit/webkit/blob/master/Tools/Scripts/webkitdirs.pm

# debug: $(appdir)/test.app
# http://stackoverflow.com/questions/24715891/access-a-swift-repl-in-cocoa-programs
dbg.app: $(appdir)/$(macpin).app
	lldb -f $^/Contents/MacOS/$(macpin) -- -i #|| { echo $$?; [ -t 1 ] && stty sane; }

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

wkdoc:
	{ for i in WebKitPrivates; do echo ":print_module $$i" | $(env) xcrun swift $(swift) $(debug) $(incdirs) -swift-version $(swiftver) -suppress-warnings -Xfrontend -color-diagnostics -deprecated-integrated-repl; done ;} | { [ -t 1 ] && less || cat; }

# need to gen static html with https://github.com/realm/jazzy
doc stpdoc: $(lexecs) $(objs)
	{ for i in $(build_mods) WebKit WebKitPrivates JavaScriptCore; do echo ":print_module $$i" | $(env) xcrun swift $(swift) $(debug) $(incdirs) -swift-version $(swiftver) -suppress-warnings -Xfrontend -color-diagnostics -deprecated-integrated-repl; done ;} | { [ -t 1 ] && less || cat; }
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
	zip -9 -r $@ extras/*.workflow --exclude @extras/.zipignore
	cd $(appdir) && zip -g -ws -r $@ *.app --exclude @$(realpath $+)
# zip can't do head-to-tail cross-file dedup ... so astoundingly poor non-compression of all the duplicate SwiftSupport/*s

txz: $(TXZ)
$(TXZ): .zipignore
	[ ! -f $(TXZ) ] || rm $(TXZ)
	cd $(appdir) && tar -v -c --xz -f $@ -X $(realpath $+) *.app
# Archive Utility after 10.10 has a bug with unpacking these ...

dmg: $(DMG)
$(DMG):
	hdiutil create -srcfolder "$(appdir)" -format UDZO -imagekey zlib-level=9 "$@" -volname "$(macpin) $(VERSION)" -scrub -quiet

release: clean tag allapps $(ZIP)
ifneq ($(GITHUB_ACCESS_TOKEN),)
upload: release
	git push -f --tags
	posturl=$$(curl -u $(USER):$(GITHUB_ACCESS_TOKEN) --data $(GH_RELEASE_JSON) "https://api.github.com/repos/$(USER)/$(REPO)/releases" | jq -r .upload_url | sed 's/{.*//g') && [ -n "$$posturl" ] && \
	dload=$$(curl -u $(USER):$(GITHUB_ACCESS_TOKEN) --fail -X POST -H "Content-Type: application/gzip" --data-binary "@$(ZIP)" "$${posturl}?name=$(notdir $(ZIP))" | jq -r .browser_download_url | sed 's/[\{\}]//g') && \
	echo "$(REPO) now available for download at $$dload"
else
upload:
	# https://developer.github.com/v3/auth/#basic-authentication
	@echo You need to export \$$GITHUB_ACCESS_TOKEN to make an upload!
	@exit 1
endif

wk_symbols:
	symbols "$(webkitdir)/Versions/A/WebKit" | less

jsc_symbols:
	symbols "$(jscdir)/Versions/A/JavaScriptCore" | less

jsc:
	$(env) "$(jscdir)/Resources/jsc" -i

stp_symbols:
	symbols "$(stpframes)/WebKit.framework/Versions/A/WebKit" | less
	symbols "$(stpframes)/JavaScriptCore.framework/Versions/Current/JavaScriptCore" | less
	symbols "$(stpframes)/Safari.framework/Versions/Current/Safari" | less

stp_jsc:
	JSC_useDollarVM=1 JSC_reportCompileTimes=true JSC_logHeapStatisticsAtExit=true \
	$(env) "$(stpframes)/JavaScriptCore.framework/Resources/jsc" -i

$(V).SILENT: # enjoy the silence
.PRECIOUS: $(appdir)/%.app/Info.plist $(appdir)/%.app/Contents/Info.plist $(appdir)/%.app/entitlements.plist $(appdir)/%.app/Contents/entitlements.plist $(appdir)/%.app/Contents/Resources/Icon.icns $(xcassets)/%.xcassets $(appdir)/%.app/Assets.car $(appdir)/%.app/LaunchScreen.nib $(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings $(appdir)/%.app/en.lproj/InfoPlist.strings $(outdir)/%.entitlements.plist $(appdir)/%.app/Contents/SwiftSupport $(outdir)/Frameworks/%.framework $(outdir)/Frameworks/%.framework/Versions/A/Resources/Info-macOS.plist $(outdir)/Frameworks/%.framework/Versions/A/Frameworks
.PHONY: clean install reset uninstall reinstall test test.app test.ios stp stp.app apirepl tabrepl allapps tag release doc stpdoc swiftrepl %.app zip $(ZIP) upload sites/% modules/% submake_% statics dynamics stp_symbols stp_jsc
.SUFFIXES:
