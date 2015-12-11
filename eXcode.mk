# Makefile.eXcode: making ObjC & Swift apps without .xcodeproj
# it's no CocoaPods, but it's as "simple":

# import this near the top of your Makefile, only input variable is $builddir
# then put your ObjC & Swift code into modules/<import-name>
# ObjC modules will need module.modulemap files to describe their headers and linkage
#  -> http://clang.llvm.org/docs/Modules.html http://llvm.org/devmtg/2012-11/Gregor-Modules.pdf
# run make and resulting targets will be printed
# depend on those targets in your Makefile to generate .apps

eXcode := $(lastword $(MAKEFILE_LIST))

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
archs_iphoneos		?= armv7 armv7s arm64
arch				?= $(shell uname -m)

target_ver_OSX		?= 10.11
target_OSX			?= apple-macosx$(target_ver_OSX)
target_ver_iOS		?= 9.1
target_iOS			?= apple-ios$(target_ver_iOS)
target				?= $(target_OSX)

ifneq ($(SIM_ONLY),)
sdk := iphonesimulator
platform := iOS
target := $(target_iOS)
else ifneq ($(A9_ONLY),)
sdk := iphoneos
platform := iOS
target := $(target_iOS)
arch := arm64
archs_iphoneos := arm64
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
cross: ; @echo [$(eXcode)] Finished target $@: $^
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
$(info [$(eXcode)] $$(platform) := $(platform))
$(info [$(eXcode)] $$(arch) := $(arch))
$(info [$(eXcode)] $$(sdk) := $(sdk))
$(info [$(eXcode)] $$(target) := $(target))
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
#incdirs += /Applications/Xcode.app/Contents/Developer//Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/$(sdk)/$(arch)/

#find all modules with compilable source code
build_mods			:= $(sort $(filter-out %/$(platform),$(patsubst modules/%/,%,$(dir $(wildcard modules/*/*.m modules/*/$(platform)/*.m modules/*/*.swift modules/*/$(platform)/*.swift)))))
$(info [$(eXcode)] $$(build_mods) (compilable modules): $(build_mods))

#modules with compilable main() routines that can be built into executables
exec_mods			:= $(sort $(patsubst %/$(platform),%,$(patsubst modules/%/,%,$(dir $(wildcard modules/*/main.swift modules/*/$(platform)/main.swift)))))
exec_mods			:= $(sort $(exec_mods) $(patsubst %/$(platform),%,$(patsubst modules/%/,%,$(dir $(shell grep -l -s -e ^@NSApplicationMain -e ^@UIApplicationMain modules/*/*.swift modules/*/$(platform)/*.swift)))))
execs				:= $(exec_mods:%=$(outdir)/exec/%)
$(info [$(eXcode)] $$(execs) (executables available to assemble): $(execs))

#assume modules that ship executables will not need to be made into intermediate objects nor libraries
build_mods			:= $(filter-out $(exec_mods),$(build_mods))

# any modules left should be built into static libraries
statics				:= $(patsubst %,$(outdir)/obj/lib%.a,$(build_mods:modules/%=%))
$(info [$(eXcode)] $$(statics) (static libraries available to build): $(statics))
#statics:	$(statics);

dynamics			:= $(patsubst %,$(outdir)/Frameworks/lib%.dylib,$(build_mods:modules/%=%))
$(info [$(eXcode)] $$(dynamics) (dynamic libraries available to build): $(dynamics))
#dynamics:	$(dynamics);

#objs				:= $(patsubst %,$(outdir)/obj/%.o,$(build_mods:modules/%=%))
#$(info $(eXcode) - Objects available to build: $(objs))

#libs				:= $(patsubst %,$(outdir)/Frameworks/lib%.dylib,$(build_mods:modules/%=%))
#$(info $(eXcode) - Libraries available to build: $(libs))
###########################

# llvm scaffolding
###################
debug				?=
verbose				?=

sdkpath				:= $(shell xcrun --show-sdk-path --sdk $(sdk))
swiftc				:= xcrun -sdk $(sdk) swiftc -target $(arch)-$(target_$(platform)) $(verbose)
clang				:= xcrun -sdk $(sdk) clang -fmodules -target $(arch)-$(target_$(platform)) $(verbose)
#-fobj-arc

libdirs				:= -L $(outdir)/Frameworks -L $(outdir)/obj
incdirs				+= -I $(outdir)
os_frameworks		:= -F $(sdkpath)/System/Library/Frameworks -L $(sdkpath)/System/Library/Frameworks
frameworks			:= -F $(outdir)/Frameworks
swiftlibdir			:= $(lastword $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift/$(sdk) $(shell xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/$(sdk)))
swiftstaticdir		:= $(lastword $(wildcard /Library/Developer/CommandLineTools/usr/lib/swift_static/$(sdk) $(shell xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift_static/$(sdk)))
$(info [$(eXcode)] compiling against $(sdkpath))
$(info [$(eXcode)] swift libraries: $(swiftlibdir) $(swiftstaticdir))
ifeq ($(platform),OSX)
clang += -mmacosx-version-min=$(target_ver_OSX)
else ifeq ($(platform),iOS)
clang += -miphoneos-version-min=$(target_ver_iOS)
endif

$(swiftlibdir):
	xcode-select --install
########################

$(outdir)/MacOS $(outdir)/exec $(outdir)/Frameworks $(outdir)/obj $(outdir)/Contents $(outdir)/SwiftSupport: ; install -d $@

define bundle_libswift
	for lib in $$(otool -L $@ | awk -F '[/ ]' '$$2 ~ /^libswift.*\.dylib/ { printf $$2 " " }'); do \
		cp $(swiftlibdir)/$$lib $(outdir)/SwiftSupport; \
		for sublib in $$(otool -L $(swiftlibdir)/$$lib | awk -F '[/ ]' '$$2 ~ /libswift.*\.dylib/ { printf $$2 " " }'); do \
			[ ! -f $(outdir)/SwiftSupport/$$sublib ] && cp $(swiftlibdir)/$$sublib $(outdir)/SwiftSupport; \
		done; \
	done;
endef
#^ my hope is that Swift will eventually become a system framework when Apple starts using it to build iOS/OSX system apps ...
#  https://forums.developer.apple.com/message/9714
#  http://mjtsai.com/blog/2015/06/12/swift-libraries-not-included-in-ios-9-or-el-capitan/

#$(outdir)/exec/%: libdirs += -L $(swiftlibdir)
$(outdir)/exec/%: $(outdir)/obj/%.o | $(outdir)/exec $(outdir)/Frameworks $(outdir)/SwiftSupport
	# grab the .d's of $^ and build any used modules ....
	$(clang) $(libdirs) $(os_frameworks) $(frameworks) -L $(swiftlibdir) -Wl,-rpath,@loader_path/../Frameworks -Wl,-rpath,@loader_path/../SwiftSupport -o $@ $^
	$(bundle_libswift)

# this is for standalone utility/helper programs, use module/main.swift for Application starters
$(outdir)/exec/%: execs/$(platform)/%.swift | $(outdir)/exec
	$(swiftc) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(libdirs) $(linklibs) \
		-Xlinker -rpath -Xlinker @loader_path/../Frameworks \
		-Xlinker -rpath -Xlinker @loader_path/../SwiftSupport \
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
		$(filter %.swift,$^)

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

$(outdir)/obj/lib%.a: $(outdir)/obj/%.o
	libtool -static -o $@ $^

$(outdir)/libswift%.a: $(outdir)/obj/lib%.a
	lipo -output $@ -create $^

.PRECIOUS: $(outdir)/Frameworks/lib%.dylib $(outdir)/obj/%.o $(outdir)/exec/% $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc
.PHONY: submake_% statics dynamics
.LIBPATTERNS: lib%.dylib lib%.a
MAKEFLAGS += --no-builtin-rules
