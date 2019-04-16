# Makefile.eXcode: making ObjC & Swift apps without .xcodeproj
# it's no CocoaPods, but it's as "simple":

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
platforms			?= OSX iOS
platform			?= OSX

sdks				?= macosx iphoneos iphonesimulator
sdks_OSX			?= macosx
sdks_iOS			?= iphoneos iphonesimulator
sdk					?= macosx

archs_macosx		?= i386 x86_64
archs_iphonesimulator	?= $(archs_macosx)
archs_iphoneos		?= armv7 arm64
arch				?= $(shell uname -m)

target_ver_OSX		?= 10.11
target_OSX			?= apple-macosx$(target_ver_OSX)
target_ver_iOS		?= 9.1
target_iOS			?= apple-ios$(target_ver_iOS)
target				?= $(target_OSX)

ifeq (sim,$(only))
$(info Only building for iOS Simlator)
sdk := iphonesimulator
platform := iOS
target := $(target_iOS)
else ifeq (a7,$(only))
$(info Only building for iphone5s+, ipad Air, ipad Mini Retina)
sdk := iphoneos
platform := iOS
target := $(target_iOS)
arch := arm64
archs_iphoneos := arm64
else ifeq (a6,$(only))
$(info Only building for iphone5, ipad4)
sdk := iphoneos
platform := iOS
target := $(target_iOS)
arch := armv7
archs_iphoneos := armv7
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
build_mods			:= $(sort $(filter-out %/$(platform),$(patsubst modules/%/,%,$(dir $(wildcard modules/*/*.m modules/*/$(platform)/*.m modules/*/*.swift modules/*/$(platform)/*.swift modules/*/*.mm modules/*/$(platform)/*.mm)))))
$(info modules/ => $(build_mods))

#modules with compilable main() routines that can be built into executables
exec_mods			:= $(sort $(patsubst %/$(platform),%,$(patsubst modules/%/,%,$(dir $(wildcard modules/*/main.swift modules/*/$(platform)/main.swift)))))
exec_mods			:= $(sort $(exec_mods) $(patsubst %/$(platform),%,$(patsubst modules/%/,%,$(dir $(shell grep -l -s -e ^@NSApplicationMain -e ^@UIApplicationMain modules/*/*.swift modules/*/$(platform)/*.swift)))))
execs				:= $(exec_mods:%=$(outdir)/exec/%)
#$(info [$(eXmk)] $$(execs) (executables available to assemble): $(execs))

#assume modules that ship executables will not need to be made into intermediate objects nor libraries
build_mods			:= $(filter-out $(exec_mods),$(build_mods))

# any modules left should be built into static libraries
statics				:= $(patsubst %,$(outdir)/obj/lib%.a,$(build_mods:modules/%=%))
#$(info [$(eXmk)] $$(statics) (static libraries available to build): $(statics))
#statics:	$(statics);

dynamics			:= $(patsubst %,$(outdir)/Frameworks/lib%.dylib,$(build_mods:modules/%=%))
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
# Xcode.app/Contents/Developer/Toolchains/*.xctoolchain/ToolchainInfo.plist << TC ids in there

sdkpath				:= $(shell $(xcrun) --show-sdk-path --sdk $(sdk))
# https://github.com/apple/swift/blob/master/include/swift/Option/Options.td
# https://github.com/apple/swift/blob/master/include/swift/Option/FrontendOptions.td
# https://github.com/apple/swift/blob/master/docs/Diagnostics.md
# https://www.bignerdranch.com/blog/build-log-groveling-for-fun-and-profit-manual-swift-continued/
swflags				:= $(SWFTFLAGS) $(SWCCFLAGS:%=-Xcc %) -swift-version $(swiftver) -target $(arch)-$(target_$(platform)) $(swflags) -Xfrontend -color-diagnostics $(verbose)
swiftc				:= $(xcrun) --toolchain com.apple.dt.toolchain.$(swifttoolchain) -sdk $(sdk) swiftc $(swflags)
swift-update		:= $(xcrun) --toolchain com.apple.dt.toolchain.$(swifttoolchain) -sdk $(sdk) swift-update $(swflags)
# https://github.com/apple/swift/tree/master/lib/Migrator
swift-migrate		:= $(xcrun) --toolchain com.apple.dt.toolchain.$(swifttoolchain) -sdk $(sdk) swiftc -update-code $(swflags)
clang				:= $(xcrun) -sdk $(sdk) clang -fmodules -target $(arch)-$(target_$(platform)) $(verbose)
clangpp				:= $(xcrun) -sdk $(sdk) clang++ -fmodules -fcxx-modules -std=c++11 -stdlib=libc++ -target $(arch)-$(target_$(platform)) $(verbose)
#-fobj-arc
#-fobjc-call-cxx-cdtors
# https://github.com/apple/swift/blob/master/tools/swift-stdlib-tool/swift-stdlib-tool.mm
swift-stdlibtool	:= $(xcrun) --toolchain com.apple.dt.toolchain.$(swifttoolchain) -sdk $(sdk) swift-stdlib-tool --platform $(sdk)


libdirs				:= -L $(outdir)/Frameworks -L $(outdir)/obj
incdirs				+= -I $(sdkpath)/System/Library/Frameworks
#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/System/Library/Frameworks
incdirs				+= -I $(outdir)
os_frameworks		:= -F $(sdkpath)/System/Library/Frameworks -L $(sdkpath)/System/Library/Frameworks
frameworks			:= -F $(outdir)/Frameworks
swiftlibdir			:= $(lastword $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift/$(sdk) $(shell $(xcs) -p)/Toolchains/$(swifttoolchain).xctoolchain/usr/lib/swift/$(sdk)))
swiftstaticdir		:= $(lastword $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift_static/$(sdk) $(shell $(xcs) -p)/Toolchains/$(swifttoolchain).xctoolchain/usr/lib/swift_static/$(sdk)))
$(info $(platform) sdk:)
$(info =>    $(sdkpath))
$(info swiftlibs:)
$(info =>    $(swiftlibdir))
$(info =>    $(swiftstaticdir))
$(info swiftc:)
$(info =>    $(shell $(swiftc) --version))
ifeq ($(platform),OSX)
clang += -mmacosx-version-min=$(target_ver_OSX)
else ifeq ($(platform),iOS)
clang += -miphoneos-version-min=$(target_ver_iOS)
endif

$(swiftlibdir):
	xcode-select --install
########################

$(outdir)/MacOS $(outdir)/exec $(outdir)/Frameworks $(outdir)/obj $(outdir)/Contents: ; install -d $@

define bundle_libswift
	for lib in $$(otool -L $@ | awk -F '[/ ]' '$$2 ~ /^libswift.*\.dylib/ { printf $$2 " " }'); do \
		cp $(swiftlibdir)/$$lib $(outdir)/SwiftSupport; \
		for sublib in $$(otool -L $(swiftlibdir)/$$lib | awk -F '[/ ]' '$$2 ~ /libswift.*\.dylib/ { printf $$2 " " }'); do \
			[ -f $(outdir)/SwiftSupport/$$sublib ] || cp $(swiftlibdir)/$$sublib $(outdir)/SwiftSupport; \
		done; \
	done;
endef
#^ my hope is that Swift will eventually become a system framework when Apple starts using it to build iOS/OSX system apps ...
#  https://forums.developer.apple.com/message/9714
#  http://mjtsai.com/blog/2015/06/12/swift-libraries-not-included-in-ios-9-or-el-capitan/
# 10.13: /System/Library/PrivateFrameworks/Swift/*.dylib for Apple's apps, ABI not vendorable until Swift5
#  https://blog.timac.org/2017/1115-state-of-swift-ios11-1-macos10-13/
#   https://github.com/apple/swift/blob/master/docs/ABIStabilityManifesto.md https://swift.org/abi-stability/
# 10.14 its happening!!
#    https://github.com/bazelbuild/rules_swift/issues/162

# https://modocache.io/swift-stdlib-tool
$(outdir)/SwiftSupport: $(outdir)/exec
	install -d $@
	$(swift-stdlibtool) --copy --verbose --scan-folder $(outdir)/exec --destination $@
	touch $@

$(outdir)/exec/%.dSYM: $(outdir)/exec/%
	dsymutil $< 2>/dev/null

#$(outdir)/exec/%: libdirs += -L $(swiftlibdir)
$(outdir)/exec/%: $(outdir)/obj/%.o | $(outdir)/exec $(outdir)/Frameworks
	# grab the .d's of $^ and build any used modules ....
	$(clang) $(debug) $(libdirs) $(os_frameworks) $(frameworks) -L $(swiftlibdir) -Wl,-rpath,/usr/lib/swift -Wl,-rpath,@loader_path/../Frameworks -Wl,-rpath,@loader_path/../SwiftSupport $(linkopts_main) -o $@ $^
	touch $(dir $@)

%.3.swift: %.swift
	$(swift-update) $^ > $@

# this is for standalone utility/helper programs, use module/main.swift for Application starters
$(outdir)/exec/%: execs/$(platform)/%.swift | $(outdir)/exec
	$(swiftc) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(libdirs) $(linklibs) \
		-Xlinker -rpath -Xlinker /usr/lib/swift \
		-Xlinker -rpath -Xlinker @loader_path/../Frameworks \
		-Xlinker -rpath -Xlinker @loader_path/../SwiftSupport \
		$(linkopts_exec) \
		-module-name $*.MainExec \
		-emit-executable -o $@ \
		$(filter %.swift,$+)

$(outdir)/Symbols/%.symbol: $(outdir)/exec/%
	# allow creation of "symbolicated crash logs" via Xcode7
	install -d %(outdir)/Symbols
	xcrun -sdk $(sdk) symbols -noTextInSOD -noDaemon -arch all -symbolsPackageDir $(outdir)/Symbols $^

$(outdir)/Frameworks/lib%.dylib $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc: modules/%/*.swift modules/%/$(platform)/*.swift | $(outdir)/Frameworks
	$(swiftc) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(libdirs) $(linklibs) \
		-parse-as-library \
		-whole-module-optimization \
		-Xlinker -install_name -Xlinker @rpath/lib$*.dylib \
 		-emit-module -module-name $* -emit-module-path $(outdir)/$*.swiftmodule \
		-emit-library -o $@ \
		$(filter-out %/main.swift,$(filter %.swift,$^))

$(outdir)/obj/%.o $(outdir)/obj/%.d $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc: modules/%/*.swift modules/%/$(platform)/*.swift | $(outdir)/obj
	$(swiftc) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(linklibs) $(libdirs) \
		-whole-module-optimization \
 		-module-name $* -emit-module-path $(outdir)/$*.swiftmodule \
		-emit-dependencies \
		-emit-object -o $@ \
		$(filter %.swift,$^)

$(outdir)/Frameworks/lib%.dylib: modules/%/*.m | $(outdir)/Frameworks
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

modules.$(nextswiftver)/%/: modules.$(swiftver)/%/*.swift modules.$(swiftver)/%/$(platform)/*.swift
	install -v -d $@
	$(swift-migrate) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(linklibs) $(libdirs) \
		-o /dev/null \
		$(filter %.swift,$^) || { rm -vrf $@; exit 1; }
	# -c -primary-file this.swift -emit-migrated-file-path that.swift

.PRECIOUS: $(outdir)/Frameworks/lib%.dylib $(outdir)/obj/%.o $(outdir)/exec/% $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc
.PHONY: submake_% statics dynamics
.LIBPATTERNS: lib%.dylib lib%.a
MAKEFLAGS += --no-builtin-rules
