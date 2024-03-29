#!/usr/bin/make -rf
export
#^ export all the variables
builddir			?= build

VERSION				:= 2022.0.0

macpin				:= MacPin
macpin_sites		?= sites
installdir			:= ~/Applications/MacPin.localized
bundle_untracked	?= 0
appnames			= $(patsubst $(macpin_sites)/%,%.app,$(wildcard $(macpin_sites)/*))

usage help:
	@printf '\nusage:\tmake (V=1) <target>\n\ntargets:\n%s'
	@printf '\t%s\n' allapps reinstall uninstall test test.app sites/*

include eXcode.mk
mk := $(firstword $(MAKEFILE_LIST))
$(info )
$(info [$(mk)])

appdir				:= $(outdir)/apps

# now layout the MacPin .app targets to generate based on eXcode's build targets
$(info $(macpin_sites)/* => $(appdir) => $(installdir)/*.app)

gen_apps			= $(patsubst $(macpin_sites)/%,$(appdir)/%.app,$(wildcard $(macpin_sites)/*))
#gen_action_exts	= $(patsubst %,$(appdir)/%.appex,$(apps))

template_bundle_id	:= com.github.kfix.MacPin
xcassets			:= $(builddir)/xcassets/$(platform)
icontypes			:= --imageset

ifeq ($(platform),macos)
icontypes			+= --iconset
else
icontypes			+= --appiconset
endif

# http://www.objc.io/issue-17/inside-code-signing.html
# https://developer.apple.com/library/mac/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html#//apple_ref/doc/uid/TP40005929-CH4-SW13
# https://developer.apple.com/library/mac/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919-CH1-TNTAG20

# create this file if you want to test dev-signed iOS apps on your own devices
-include apple_dev_id.mk
#appsig				?= -
# OSX 10.15.4 seems to not run unnotarized ad-hoc-signed builds anymore
#   many CVEs https://support.apple.com/en-us/HT211100
#   https://developer.apple.com/news/?id=12232019a
#   https://gist.github.com/dpid/270bdb6c1011fe07211edf431b2d0fe4

#appsig_macos			:= Mac Developer
appsig_ios			:= iPhone Developer
# open Xcode -> Preferences -> Accounts -> +Add: Apple ID -> Manage Certificates -> +Add: iOS Development
#  `security find-identity` will then show your Developer keys you can use for appsig*:
mobileprov_team_id	?=
# https://developer.apple.com/account/#/membership/ "Team ID"

ifeq ($(platform),macos)
# make a jumbo framework and its stub launcher
# XXX: maybe we can create .xcframeworks ?
jumbolib := $(outdir)/Frameworks/$(macpin).framework
# need SharedFramework https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Tasks/InstallingFrameworks.html
jumbody := $(spm_build)/libMacPin.dylib
lexecs := $(spm_build)/MacPin_stub

# XXX: swiftpm does the building now
$(jumbody) $(jumbody).dSYM $(lexecs) $(lexecs).dSYM: Sources/MacPin/*.swift Sources/MacPinOSX/*.swift Package.swift
	@$(swiftbuild) --product MacPin
	@$(swiftbuild) --product MacPin_stub
else
# other platforms don't use the dynamiclib+stubexe
lexecs := $(spm_build)/MacPin
$(lexecs) $(lexecs).dSYM: Sources/MacPin/*.swift Sources/MacPinIOS/*.swift Package.swift
	@MACPIN_IOS=1 $(swiftbuild) --product MacPin
endif

allicons: $(patsubst %,%/Contents/Resources/Icon.icns,$(gen_apps))
allapps install: $(gen_apps)

zip test apirepl tabrepl $(gen_apps): $(lexecs)
zip test apirepl tabrepl test.app test.ios: | $(lexecs:%=%.dSYM)

# older OSX/macOS with backported Safari.app have vendored WK/JSC frameworks
env += DYLD_PRINT_LIBRARIES_POST_LAUNCH=1

webkitdir				?= /System/Library/Frameworks/WebKit.framework
jscdir					?= /System/Library/Frameworks/JavaScriptCore.framework

webkitver				:= $(shell defaults read "$(webkitdir)/Resources/Info" CFBundleVersion)
$(info $(webkitdir) => $(webkitver))

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
ZIP			 := $(outdir)/$(REPO)-$(platform)-$(arch)-$(VERSION).zip
TXZ			 := $(outdir)/$(REPO)-$(platform)-$(arch)-$(VERSION).tar.xz
DMG			 := $(outdir)/$(REPO)-$(platform)-$(arch)-$(VERSION).dmg
GH_RELEASE_JSON = '{"tag_name": "v$(VERSION)","target_commitish": "master","name": "v$(VERSION)","body": "MacPin $(plaform) $(arch) build of version $(VERSION)","draft": false, "prerelease": true}'
#####

$(xcassets)/%.xcassets: $(macpin_sites)/%/icon.png
	$(swiftrun_mac) iconify $(icontypes) $< $@

$(xcassets)/%.xcassets: templates/xcassets/$(platform)/%/*.png
	for i in $^; do $(swiftrun_mac) iconify --imageset $$i $@; done

$(xcassets)/%.xcassets: templates/xcassets/%/*.png
	for i in $^; do $(swiftrun_mac) iconify --imageset $$i $@; done

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
ifeq ($(platform),macos)
	[ ! -f $(macpin_sites)/$*/ServicesOSX.plist ] || /usr/libexec/PlistBuddy -c 'merge $(macpin_sites)/$*/ServicesOSX.plist :NSServices' -c save $@
endif

$(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings $(appdir)/%.app/en.lproj/InfoPlist.strings: templates/$(platform)/InfoPlist.strings
	$(gen_plist_template)

# https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/SystemExtensionKeys.html#//apple_ref/doc/uid/TP40014212-SW17
$(appdir)/%/Contents/PlugIns/ActionExtension.appex/Contents/Info.plist $(appdir)/%.appex/Info.plist: templates/appex/$(platform)/Info.plist
	$(gen_plist_template)

# https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html
# TODO: use WK-API to enable "(Remote (Safari)) Inspectability" instead of the entitlements: https://github.com/WebKit/WebKit/commit/a0a26311c18df6a6b7aa596ee06ee0b4257f765a
$(outdir)/%.entitlements.plist: templates/$(platform)/entitlements.plist
	$(gen_plist_template)

# phony targets for cmdline convenience
%.dSYM: $(appdir)/%.dSYM
sites/% %.app: $(appdir)/%.app
	@echo Finished building $<
#modules/%: $(outdir)/obj/%.o

test_%: $(appdir)/%.app | $(appdir)/MacPin.app
	-/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -v $(outdir)/apps/ -apps com.github.kfix.MacPin.MacPin
	($(env) $^/Contents/MacOS/$(basename $(notdir $^)) -i)

ifeq ($(platform),macos)

#--platform $(sdk)\ 
$(appdir)/%.app/Contents/Resources/Icon.icns $(appdir)/%.app/Contents/Resources/Assets.car: $(xcassets)/%.xcassets
	@install -d $(dir $@)
	xcrun actool --output-format human-readable-text --notices --warnings --print-contents --output-partial-info-plist $@.plist \
	    --platform macosx \
		--minimum-deployment-target 10.12 --target-device mac \
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
	@touch $@

$(outdir)/Frameworks/%.framework: $(jumbody) $(jumbody).dSYM $(outdir)/Frameworks/%.framework/Versions/A/Frameworks $(outdir)/Frameworks/%.framework/Versions/A/Resources/Info-macOS.plist
	@install -dv $@
	@rm -rfv $@/Versions/Current $@/Resources $@/Frameworks %@/$*
	@ln -sf A $@/Versions/Current
	@ln -sf Versions/Current/$* $@/$*
	@ln -sf Versions/Current/Resources $@/Resources
	@ln -sf Versions/Current/Frameworks $@/Frameworks
	@cp -RL $(jumbody) $@/Versions/A/$*
	@cp -RL $(jumbody).dSYM $@/Versions/A/$*.dSYM
	# need a Resources/Info-macos.plist & version.plist
	-[ ! -n "$(codesign)" ] || codesign --verbose=4 --sign '$(appsig)' --timestamp --options runtime --force --deep --ignore-resources --strict --entitlements $(outdir)/$*.entitlements.plist $@

#build the app bundle
$(appdir)/%.app: $(macpin_sites)/% $(macpin_sites)/%/* $(appdir)/%.app/Contents/Info.plist $(outdir)/%.entitlements.plist $(appdir)/%.app/Contents/Resources/Icon.icns templates/Resources/ $(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings $(lexecs)
	@install -d $@ $@/Contents/MacOS $@/Contents/Resources
	COMMAND_MODE=legacy cp -f $(lexecs) $@/Contents/MacOS/$*
	#[ -z "$(debug)" ] || $(patsubst %,cp -RL % $@/Contents/MacOS/$*.dSYM,$(filter $(outdir)/exec/%.dSYM,$^))
	COMMAND_MODE=legacy cp -fRL templates/Resources $@/Contents
	#git ls-files -zc $(bundle_untracked) $(macpin_sites)/$* | xargs -0 -J % install -DT % $@/Contents/Resources/
	(($(bundle_untracked))) || git archive HEAD $(macpin_sites)/$*/ | tar -xv --strip-components 2 -C $@/Contents/Resources
	(($(bundle_untracked))) && COMMAND_MODE=legacy cp -fRL $(macpin_sites)/$*/* $@/Contents/Resources/ || true
	[ ! -d $@/Contents/Resources/Library ] || ln -sfh Resources/Library $@/Contents/Library
	plutil -replace NSHumanReadableCopyright -string "built $(shell date) by $(shell id -F)" $@/Contents/Info.plist >/dev/null
	[ ! -f "$(macpin_sites)/$*/Makefile" ] || $(MAKE) -C $@/Contents/Resources
	plutil -convert xml1 $(outdir)/$*.entitlements.plist
	[ ! -n "$(codesign)" ] || codesign --verbose=4 --sign '$(appsig)' --timestamp --force --ignore-resources --entitlements $(outdir)/$*.entitlements.plist $@
	-codesign --display -r- --verbose=4 --deep --entitlements :- $@
	-spctl -vvvv --assess --type execute $@ # App Store-ability
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

else ifeq ($(platform),ios)

$(appdir)/%.app/Assets.car: $(xcassets)/%.xcassets $(xcassets)/icons8.xcassets
	@install -d $(dir $@)
	xcrun actool --output-format human-readable-text --notices --warnings --print-contents --output-partial-info-plist $@.plist \
		--platform $(sdk) --minimum-deployment-target $(target_ver_ios)  --target-device iphone  --target-device ipad --app-icon AppIcon \
		--compress-pngs --compile $(dir $@) $(realpath $(filter %.xcassets, $^)) > /dev/null
	test -f $@ || { echo "error: $@ was not created by actool!" && cat $@.plist && exit 1; }

$(appdir)/%.app/LaunchScreen.nib: templates/$(platform)/LaunchScreen.xib
	@install -d $(dir $@)
	ibtool --compile $@ $<

$(appdir)/%.app: $(macpin_sites)/% $(macpin_sites)/%/* $(outdir)/%.entitlements.plist $(appdir)/%.app/Info.plist templates/$(platform)/LaunchScreen.xib $(appdir)/%.app/LaunchScreen.nib $(appdir)/%.app/Assets.car templates/Resources templates/Resources/* $(appdir)/%.app/en.lproj/InfoPlist.strings $(lexecs)
	install -d $@
	COMMAND_MODE=legacy cp -f $(lexecs) $@/$*
	#[ -z "$(debug)" ] || $(patsubst %,cp -RL % $@/$*.dSYM;,$(filter $(outdir)/exec/%.dSYM,$^))
	rsync -av --exclude='Library/' $(macpin_sites)/$*/ $@
	COMMAND_MODE=legacy cp -fRL templates/Resources/* $@/
	#-codesign --display -r- --verbose=4 --deep --entitlements :- $@
	-codesign --display $@
	#-spctl -vvvv --raw --assess --type execute $@
	#-asctl container acl list -file $@
	@touch $@
endif

# the main macpin app contains the core framework
$(appdir)/%.app/Frameworks: $(jumbolib)
	rm -rfv $@
	@install -dv $@
	$(patsubst %,cp -R % $@/,$(filter %.framework,$^))

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
	rm -rf $(outdir)/swiftpm $(outdir)/Frameworks

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
	($(env) $</Contents/MacOS/$(macpin) -i)

apirepl: ; ($< -i)
tabrepl: ; ($< -t)

stp.app test.app: $(appdir)/$(macpin).app
	#banner ':-}' | open -a $$PWD/$^ -f
	#-defaults delete $(template_bundle_id).$(macpin)
	#(open $^) &
	($(env) $^/Contents/MacOS/$(macpin) -i)
# https://github.com/WebKit/webkit/blob/master/Tools/Scripts/webkitdirs.pm

# debug: $(appdir)/test.app
# http://stackoverflow.com/questions/24715891/access-a-swift-repl-in-cocoa-programs
dbg.app: $(appdir)/$(macpin).app
	lldb -f $^/Contents/MacOS/$(macpin) -- -i

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
	@xcrun simctl list | grep $(shell defaults read com.apple.iphonesimulator CurrentDeviceUDID)
	# pre-A7 devices (ipad mini 2, ipad air, iphone 5s) cannot run x86_64 builds
	# if app closes without showing launch screen, try changing the simulated device to A7 or later
	xcrun simctl install booted $<
	xcrun simctl launch --console-pty booted $(template_bundle_id).$(macpin) -i
else ifeq ($(sdk),iphoneos)
test.ios: $(appdir)/$(macpin).app /usr/local/bin/ios-deploy
	ios-deploy -d -b $<
else
test.ios: ;
# make only=sim test.ios
endif

iossim.dump:
	#-tail -n100 ~/Library/Logs/CoreSimulator/$(shell defaults read com.apple.iphonesimulator CurrentDeviceUDID)/system.log
	#-@for i in ~/Library/Logs/DiagnosticReports/$(macpin)_$(shell date +%Y-%m-%d-%H%M)*_$(shell scutil --get LocalHostName).crash; do [ -f $$i ] && cat $$i && echo $$i; break; done
	xcrun simctl diagnose -l

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
	tar -v -C $(appdir) -c -f $@ -X $(realpath $+) .

where-zip:
	$(info $(ZIP))

# zip can't do head-to-tail cross-file dedup ... so astoundingly poor non-compression of all the duplicate SwiftSupport/*s

# xcrun altool --notarize-app --primary-bundle-id {APP_BUNDLE_ID} -u {APPLE_ID} -f YOUR_APP.zip  -p "@keychain:Application Loader: {APPLE_ID}"
# xcrun stapler staple YOUR_APP.zip

where-txz:
	$(info $(TXZ))

txz: $(TXZ)
$(TXZ): .zipignore
	[ ! -f $(TXZ) ] || rm $(TXZ)
	tar -v -C $(appdir) -c --xz -f $@ -X $(realpath $+) .
# Archive Utility after 10.10 has a bug with unpacking these ...
# fixed in Big Sur (at least)

dmg: $(DMG)
$(DMG):
	hdiutil create -srcfolder "$(appdir)" -format UDZO -imagekey zlib-level=9 "$@" -volname "$(macpin) $(VERSION)" -scrub -quiet
where-dmg:
	$(info $(DMG))

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

sim_symbols:
	symbols /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/WebKit.framework/WebKit | less

where-out:
	$(info $(outdir))

$(V).SILENT: # enjoy the silence
.PRECIOUS: $(appdir)/%.app/Info.plist $(appdir)/%.app/Contents/Info.plist $(appdir)/%.app/entitlements.plist $(appdir)/%.app/Contents/entitlements.plist $(appdir)/%.app/Contents/Resources/Icon.icns $(xcassets)/%.xcassets $(appdir)/%.app/Assets.car $(appdir)/%.app/LaunchScreen.nib $(appdir)/%.app/Contents/Resources/en.lproj/InfoPlist.strings $(appdir)/%.app/en.lproj/InfoPlist.strings $(outdir)/%.entitlements.plist $(appdir)/%.app/Contents/SwiftSupport $(outdir)/Frameworks/%.framework $(outdir)/Frameworks/%.framework/Versions/A/Resources/Info-macOS.plist $(outdir)/Frameworks/%.framework/Versions/A/Frameworks
.PHONY: clean install reset uninstall reinstall test test.app test.ios apirepl tabrepl allapps tag release  %.app zip $(ZIP) txz $(TXZ) upload sites/% modules/% submake_% wk_symbols jsc_symbols jsc sim_symbols where-txz where-zip where-dmg where-out
.SUFFIXES:
