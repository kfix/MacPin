# Makefile.eXcode: making ObjC & Swift apps without .xcodeproj
# it's no CocoaPods, but it's as "simple":
# TODO look into SPM or https://github.com/apple/swift-llbuild ?

#SHELL=/bin/bash -O nullglob -c

# import this near the top of your Makefile, only input variable is $builddir
# then put your ObjC & Swift code into modules/<import-name>
# ObjC modules will need module.modulemap files to describe their headers and linkage
#  -> http://clang.llvm.org/docs/Modules.html http://llvm.org/devmtg/2012-11/Gregor-Modules.pdf
# run make and resulting targets will be printed
# depend on those targets in your Makefile to generate .apps

eXmk := $(lastword $(MAKEFILE_LIST))
$(info [$(eXmk)])

# Cross-Compilation via Recursive Make Madness
########################
#installed_sdks		!= xcodebuild -showsdks | awk '$NF > 1 && $(NF-1)=="-sdk" {printf $NF " "}'
platforms			?= macos ios
platform			?= macos

sdks				?= macosx iphoneos iphonesimulator
sdks_macos			?= macosx
sdks_ios			?= iphoneos iphonesimulator
sdks_iosmac			?= macosx
sdk					?= macosx

archs_macosx		?= x86_64
archs_iphonesimulator	?= x86_64
archs_iphoneos		?= armv7 arm64
arch				?= $(shell uname -m)

target_ver_macos	?= 10.11
target_macos		?= apple-macos$(target_ver_macos)
target_ver_ios		?= 9.1
target_ios			?= apple-ios$(target_ver_ios)
target				?= $(target_macos)

# Variants
ifeq (sim,$(only))
$(info Only building for iOS Simulator)
sdk := iphonesimulator
platform := ios
target := $(target_ios)-simulator
else ifeq (a7,$(only))
$(info Only building for iphone5s+, ipad Air, ipad Mini Retina)
sdk := iphoneos
platform := ios
target := $(target_ios)
arch := arm64
archs_iphoneos := arm64
else ifeq (a6,$(only))
$(info Only building for iphone5, ipad4)
sdk := iphoneos
platform := ios
target := $(target_ios)
arch := armv7
archs_iphoneos := armv7
else ifeq (uikit,$(only))
$(info Only building for UIKit-on-Mac)
sdk := macosx
platform := ios
target_ver_ios		?= 13.0
target_ios	:= apple-ios$(target_ver_ios)-macabi
target	:= $(target_ios)
arch := x86_64
endif

outdir				:= $(builddir)/$(sdk)-$(arch)-$(target_$(platform))

#-> platform, sdk, arch, target
#$(info $(0) $(1) $(2) $(3) $(4))
define REMAKE_template
submake_$(1)_$(2)_$(3)_$(4): ; $$(MAKE) platform=$(1) sdk=$(2) arch=$(3) target=$(4) $(filter-out cross,$(MAKECMDGOALS))
allarchs += submake_$(1)_$(2)_$(3)_$(4)
cross: submake_$(1)_$(2)_$(3)_$(4)
endef

ifeq (0,$(MAKELEVEL))
# this is the parent invocation of make
allarches	=

cross: ; @echo [$(eXmk)] Finished target $@: $^
$(foreach platform,$(platforms), \
	$(foreach sdk,$(sdks_$(platform)), \
		$(foreach arch,$(archs_$(sdk)), \
			$(eval $(call REMAKE_template,$(platform),$(sdk),$(arch),$(target_$(platform))));\
		) \
	) \
)
#$(info $(call REMAKE_template,$(platform),$(sdk),$(arch),$(target)))
else
# we are in a submake
endif
#$(info [$(eXmk)] $$(platform) := $(platform))
#$(info [$(eXmk)] $$(arch) := $(arch))
#$(info [$(eXmk)] $$(sdk) := $(sdk))
#$(info [$(eXmk)] $$(target) := $(target))
###########################

# This is some poetry to figure out what in modules/* is compilable to objects, libraries, and executables
# you may need to add linkage dependencies to specific object targets if swift/clang can't figure them out from *.modulemap and *.swiftmodule
#   someobj.o: linklibs := -lSomeLib -lFooThing.o
#	someobj.o: linkdirs := -L /opt/SomeProductWithSomeLib/lib
#	someobj.o: FooThing.o
# todo: support Carthage deps https://github.com/Carthage/Carthage
###########################

#modules with clang modulemaps (and probably associated C-headers and linklib hints)
incdirs				:= -I modules
# ^ clang will recurse one more level to check modules/*/*.modulemaps
#incdirs += /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/$(sdk)/$(arch)/

#find all modules with compilable source code
build_mods			:= $(sort $(filter-out %/_$(platform),$(patsubst modules/%/,%,$(dir $(wildcard modules/*/*.m modules/*/_$(platform)/*.m modules/*/*.swift modules/*/_$(platform)/*.swift modules/*/*.mm modules/*/_$(platform)/*.mm)))))
$(info modules/ => $(build_mods))

#modules with compilable main() routines that can be built into executables
exec_mods			:= $(sort $(patsubst %/_$(platform),%,$(patsubst modules/%/,%,$(dir $(wildcard modules/*/main.swift modules/*/_$(platform)/main.swift)))))
exec_mods			:= $(sort $(exec_mods) $(patsubst %/_$(platform),%,$(patsubst modules/%/,%,$(dir $(shell grep -l -s -e ^@NSApplicationMain -e ^@UIApplicationMain modules/*/*.swift modules/*/_$(platform)/*.swift)))))
execs				:= $(exec_mods:%=$(outdir)/exec/%)
lexecs				:= $(exec_mods:%=$(outdir)/lexec/%)
#$(info [$(eXmk)] $$(execs) (executables available to assemble): $(execs))

#assume modules that ship executables will not need to be made into intermediate objects nor libraries
#build_mods			:= $(filter-out $(exec_mods),$(build_mods))

# any modules left should be built into static libraries
statics				:= $(patsubst %,$(outdir)/obj/lib%.a,$(build_mods:modules/%=%))
#$(info [$(eXmk)] $$(statics) (static libraries available to build): $(statics))
#statics:	$(statics);

dynamics			:= $(patsubst %,$(outdir)/obj/lib%.dylib,$(build_mods:modules/%=%))
#$(info [$(eXmk)] $$(dynamics) (dynamic libraries available to build): $(dynamics))
#dynamics:	$(dynamics);

#objs				:= $(patsubst %,$(outdir)/obj/%.o,$(build_mods:modules/%=%))
#$(info $(eXmk) - Objects available to build: $(objs))

updates				:= $(patsubst %,$(outdir)/swup/%,$(exec_mods:modules/%=%))
#$(info [$(eXmk)] $$(updates) (swift modules available to update): $(updates))

#libs				:= $(patsubst %,$(outdir)/Frameworks/lib%.dylib,$(build_mods:modules/%=%))
#$(info $(eXmk) - Libraries available to build: $(libs))
###########################

# llvm scaffolding
###################
debug				?=
verbose				?=
xcrun				?= xcrun
xcs					?= xcode-select

swiftver			?= 3
nextswiftver		?= 4
swifttoolchain		?= XcodeDefault
swifttoolchaindir   ?= /Applications/Xcode.app/Contents/Developer/Toolchains
# Xcode.app/Contents/Developer/Toolchains/*.xctoolchain/ToolchainInfo.plist << TC ids in there
swifttoolchainid 	?= com.apple.dt.toolchain.$(swifttoolchain)

sdkpath				?= $(shell $(xcrun) --show-sdk-path --sdk $(sdk))
# https://github.com/apple/swift/blob/master/include/swift/Option/Options.td
# https://github.com/apple/swift/blob/master/include/swift/Option/FrontendOptions.td
# https://github.com/apple/swift/blob/master/docs/Diagnostics.md
# https://www.bignerdranch.com/blog/build-log-groveling-for-fun-and-profit-manual-swift-continued/
swflags				:= $(SWFTFLAGS) $(SWCCFLAGS:%=-Xcc %) -swift-version $(swiftver) -target $(arch)-$(target_$(platform)) -Xfrontend -color-diagnostics $(verbose)
swmigflags			:= $(SWFTFLAGS) $(SWCCFLAGS:%=-Xcc %) -swift-version $(nextswiftver) -target $(arch)-$(target_$(platform)) -Xfrontend -color-diagnostics $(verbose)
swiftc				:= $(xcrun) --toolchain $(swifttoolchainid) -sdk $(sdk) swiftc $(swflags)
swift-update		:= $(xcrun) --toolchain $(swifttoolchainid) -sdk $(sdk) swift-update $(swflags)
# https://github.com/apple/swift/tree/main/lib/Migrator
swift-migrate		:= $(xcrun) --toolchain $(swifttoolchainid) -sdk $(sdk) swiftc -update-code $(swmigflags)
clang				:= $(xcrun) -sdk $(sdk) clang -fmodules -target $(arch)-$(target_$(platform)) $(verbose)
clangpp				:= $(xcrun) -sdk $(sdk) clang++ -fmodules -fcxx-modules -std=c++11 -stdlib=libc++ -target $(arch)-$(target_$(platform)) $(verbose)
#-fobj-arc
#-fobjc-call-cxx-cdtors
# https://github.com/apple/swift/blob/master/tools/swift-stdlib-tool/swift-stdlib-tool.mm
swift-stdlibtool	:= $(xcrun) --toolchain $(swifttoolchainid) -sdk $(sdk) swift-stdlib-tool --platform $(sdk)


libdirs				:= -L $(outdir)/Frameworks -L $(outdir)/obj
incdirs				+= -I $(sdkpath)/System/Library/Frameworks
#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/System/Library/Frameworks
incdirs				+= -I $(outdir)
os_frameworks		:= -F $(sdkpath)/System/Library/Frameworks -L $(sdkpath)/System/Library/Frameworks
frameworks			:= -F $(outdir)/Frameworks
osswiftlibdir		:= $(lastword $(wildcard /usr/lib/swift))
swiftlibdir			:= $(lastword $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift/$(sdk) $(shell $(xcs) -p)/Toolchains/$(swifttoolchain).xctoolchain/usr/lib/swift/$(sdk)))
swiftstaticdir		:= $(lastword $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift_static/$(sdk) $(shell $(xcs) -p)/Toolchains/$(swifttoolchain).xctoolchain/usr/lib/swift_static/$(sdk)))
$(info $(platform) sdk:)
$(info =>    $(sdkpath))
$(info swiftlibs:)
$(info =>    $(swiftlibdir))
$(info =>    $(swiftstaticdir))
$(info swiftc:)
$(info =>    $(shell $(swiftc) --version))
ifeq ($(platform),macos)
clang += -mmacosx-version-min=$(target_ver_macos)
else ifeq ($(platform),ios)
clang += -miphoneos-version-min=$(target_ver_ios)
else ifneq (,$(findstring macabi,$(target))
# https://github.com/CocoaPods/CocoaPods/issues/8877#issuecomment-499258506
clang += -miphoneos-version-min=$(target_ver_ios)
swiftlibdir		:= $(lastword $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift/uikitformac $(shell $(xcs) -p)/Toolchains/$(swifttoolchain).xctoolchain/usr/lib/swift/uikitformac))
os_frameworks		:= -F $(sdkpath)/System/iOSSupport/System/Library/Frameworks -L $(sdkpath)/System/iOSSupport/System/Library/Frameworks
endif

$(swiftlibdir):
	xcode-select --install
########################

$(outdir)/MacOS $(outdir)/exec $(outdir)/lexec $(outdir)/Frameworks $(outdir)/obj $(outdir)/Contents: ; install -d $@

# https://modocache.io/swift-stdlib-tool
$(outdir)/SwiftSupport: $(outdir)/lexec
	install -d $@
	$(swift-stdlibtool) --copy --verbose --scan-folder $(outdir)/lexec --destination $@
	touch $@

$(outdir)/exec/%.dSYM $(outdir)/lexec/%.dSYM: $(outdir)/exec/%
	dsymutil $< 2>/dev/null

$(outdir)/lexec/%: modules/%/_$(platform)/main.swift | $(outdir)/lexec
	$(swiftc) $(debug) $(frameworks) $(os_frameworks) $(incdirs) $(libdirs) $(linklibs) \
		-Xlinker -rpath -Xlinker /usr/lib/swift \
		-Xlinker -rpath -Xlinker @loader_path/../SwiftSupport \
		-Xlinker -rpath -Xlinker @loader_path/../Frameworks \
		$(linkopts_exec) \
		-module-name $*.MainExec \
		-emit-executable -o $@ \
		$(filter %/main.swift,$+)

%.3.swift: %.swift
	$(swift-update) $^ > $@

# this is for standalone utility/helper programs, use module/main.swift for Application starters
$(outdir)/exec/%: execs/_$(platform)/%.swift | $(outdir)/exec
	$(swiftc) $(debug) $(frameworks) $(os_frameworks) $(incdirs) $(libdirs) $(linklibs) \
		-Xlinker -rpath -Xlinker /usr/lib/swift \
		-Xlinker -rpath -Xlinker @loader_path/../SwiftSupport \
		-Xlinker -rpath -Xlinker @loader_path/../Frameworks \
		$(linkopts_exec) \
		-module-name $*.MainExec \
		-emit-executable -o $@ \
		$(filter %.swift,$+)

$(outdir)/Symbols/%.symbol: $(outdir)/exec/%
	# allow creation of "symbolicated crash logs" via Xcode7
	install -d %(outdir)/Symbols
	xcrun -sdk $(sdk) symbols -noTextInSOD -noDaemon -arch all -symbolsPackageDir $(outdir)/Symbols $^

$(outdir)/obj/lib%.dylib $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc: modules/%/*.swift modules/%/_$(platform)/*.swift | $(outdir)/obj
	$(swiftc) $(debug) -v $(frameworks) $(os_frameworks) $(incdirs) $(libdirs) $(linklibs) \
		-parse-as-library \
		-whole-module-optimization \
		-Xlinker -install_name -Xlinker @rpath/lib$*.dylib -Xlinker -v \
 		-emit-module -module-name $* -emit-module-path $(outdir)/$*.swiftmodule \
		-emit-library -o $@ \
		$(filter-out %/main.swift,$(filter %.swift,$^)) $(extrainputs)

$(outdir)/obj/%.o $(outdir)/obj/%.d $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc: modules/%/*.swift modules/%/_$(platform)/*.swift | $(outdir)/obj
	$(swiftc) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(linklibs) $(libdirs) \
		-whole-module-optimization \
 		-module-name $* -emit-module-path $(outdir)/$*.swiftmodule \
		-emit-dependencies \
		-emit-object -o $@ \
		$(filter-out %/main.swift,$(filter %.swift,$^)) $(extrainputs)

$(outdir)/obj/lib%.dylib: modules/%/*.m | $(outdir)/obj
	$(clang) -ObjC -Wl,-dylib -Wl,-install_name,@rpath/lib$*.dylib $(os_frameworks) $(frameworks) $(incdirs) $(libdirs) $(linklibs) -o $@ $(filter %.m,$^)

#$(outdir)/%.ShareExtension.bundle: $(outdir)/%.ShareExtension/*.swift
#$(swiftc) -application-extension
# https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/SystemExtensionKeys.html#//apple_ref/doc/uid/TP40014212-SW15

$(outdir)/obj/lib%.a: modules/%/*.m | $(outdir)/obj
	mkdir $(dir $@)lib$*; cd $(dir $@)lib$*; for i in $(realpath $^); do \
		$(clang) -ObjC -c $(os_frameworks) $(frameworks) $(incdirs) $(libdirs) $(linklibs) $$i; \
	done;
	libtool -static -o $@ $(patsubst %.m,$(dir $@)lib$*/%.o,$(notdir $^))

$(outdir)/obj/lib%.a: modules/%/*.mm | $(outdir)/obj
	mkdir $(dir $@)lib$*; cd $(dir $@)lib$*; for i in $(realpath $^); do \
		$(clangpp) -ObjC++ -c $(os_frameworks) $(frameworks) $(incdirs) $(libdirs) $(linklibs) $$i; \
	done;
	libtool -static -o $@ $(patsubst %.mm,$(dir $@)lib$*/%.o,$(notdir $^))

$(outdir)/obj/lib%.a: $(outdir)/obj/%.o
	libtool -static -o $@ $^

$(outdir)/libswift%.a: $(outdir)/obj/lib%.a
	lipo -output $@ -create $^

$(outdir)/swup/%.swift: modules/%.swift
	install -v -d $(dir $@)
	$(swift-update) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(linklibs) $(libdirs) \
		$(filter %.swift,$^) > $@ || { rm -vf $@; exit 1; }
	diff -Naus $^ $@

modules.$(swiftver)/%/:
	install -v -d $@
	cp -van modules/$* $(dir $@)

modules.$(nextswiftver)/%/: modules.$(swiftver)/%/
	$(swift-migrate) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(linklibs) $(libdirs) \
		-o /dev/null \
		$(filter %,$(shell echo $+/*.swift $+/_$(platform)/*.swift))
	#|| { rm -vrf $+; exit 1; }
	cp -a $+ $@
	# -c -primary-file this.swift -emit-migrated-file-path that.swift

.PRECIOUS: $(outdir)/Frameworks/lib%.dylib $(outdir)/obj/%.o $(outdir)/exec/% $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc $(outdir)/obj/lib%.dylib
.PHONY: submake_% statics dynamics
.LIBPATTERNS: lib%.dylib lib%.a
MAKEFLAGS += --no-builtin-rules
