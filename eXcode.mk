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
archs_iphoneos		?= arm arm64
arch				?= $(shell uname -m)

target_OSX			?= apple-macosx10.10
target_iOS			?= apple-ios8.3
target				?= $(target_OSX)

ifneq ($(SIM_ONLY),)
sdk := iphonesimulator
platform := iOS
target := $(target_iOS)
endif

outdir				:= $(builddir)/$(sdk)-$(arch)-$(target_$(platform))

#-> platform, sdk, arch, target
#$(info $(0) $(1) $(2) $(3) $(4))
define REMAKE_template
submake_$(1)_$(2)_$(3)_$(4): ; $$(MAKE) platform=$(1) sdk=$(2) arch=$(3) target=$(4) IS_A_REMAKE=1 $(filter-out cross,$(MAKECMDGOALS))
allarchs += submake_$(1)_$(2)_$(3)_$(4)
cross: submake_$(1)_$(2)_$(3)_$(4)
endef

ifeq ($(IS_A_REMAKE),)
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

# some poetry to figure out what in modules/* is compilable to objects, libraries, and executables
# you may need to add linkage dependencies to specific object targets if swift/clang can't figure them out from *.modulemap and *.swiftmodule
#   someobj.o: linklibs := -lSomeLib -lFooThing.o
#	someobj.o: linkdirs := -L /opt/SomeProductWithSomeLib/lib
#	someobj.o: FooThing.o
# todo: support Carthage deps https://github.com/Carthage/Carthage
###########################

#modules with clang modulemaps (and probably associated C-headers and linklib hints)
#include_mods		:= $(sort $(patsubst %/,%,$(dir $(wildcard modules/*/*.modulemap modules/*/$(platform)/*.modulemap))))
#incdirs				+= $(addprefix -I ,$(include_mods))
incdirs				:= -I modules
# ^ clang will recurse one more level to check modules/*/*.modulemaps

#find all modules with compilable source code
build_mods			:= $(sort $(filter-out %/$(platform),$(patsubst modules/%/,%,$(dir $(wildcard modules/*/*.m modules/*/$(platform)/*.m modules/*/*.swift modules/*/$(platform)/*.swift)))))
$(info [$(eXcode)] $$(build_mods) (Compilable modules): $(build_mods))

#modules with compilable main() routines that can be built into executables
exec_mods			:= $(sort $(patsubst %/$(platform),%,$(patsubst modules/%/,%,$(dir $(wildcard modules/*/main.swift modules/*/$(platform)/main.swift)))))
exec_mods			:= $(sort $(exec_mods) $(patsubst %/$(platform),%,$(patsubst modules/%/,%,$(dir $(shell grep -l -s -e ^@NSApplicationMain -e ^@UIApplicationMain modules/*/*.swift modules/*/$(platform)/*.swift)))))
execs				:= $(exec_mods:%=$(outdir)/exec/%)
$(info [$(eXcode)] $$(execs) (Executables available to assemble): $(execs))

#assume modules that ship executables will not need to be made into intermediate objects nor libraries
build_mods			:= $(filter-out $(exec_mods),$(build_mods))

# any modules left should be built into static libraries
statics				:= $(patsubst %,$(outdir)/obj/lib%.a,$(build_mods:modules/%=%))
$(info [$(eXcode)] $$(statics) (Static Libraries available to build): $(statics))

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

libdirs				+= -L $(outdir)/Frameworks -L $(outdir)/obj
incdirs				+= -I $(outdir)
os_frameworks		+= -F $(sdkpath)/System/Library/Frameworks -L $(sdkpath)/System/Library/Frameworks
frameworks			+= -F $(outdir)/Frameworks
swiftlibdir			:= /Library/Developer/CommandLineTools/usr/lib/swift/$(sdk)
$(info [$(eXcode)] Compiling against $(sdkpath))
ifeq ($(platform),OSX)
clang += -mmacosx-version-min=10.10
else ifeq ($(platform),iOS)
clang += -miphoneos-version-min=8.3
endif
########################

$(outdir)/MacOS $(outdir)/exec $(outdir)/Frameworks $(outdir)/obj $(outdir)/Contents: ; install -d $@

#$(outdir)/Frameworks/libswift%.dylib: $(outdir)/exec/* | $(outdir)/Frameworks
#python2.7 -m macholib find $@ | awk ...
# http://pythonhosted.org//macholib/scripts.html
# python -m macholib standalone $@
# python -m macholib find $@
define bundle_libswift
	for lib in $$(otool -L $@ | awk -F '[/ ]' '$$2 ~ /^libswift.*\.dylib/ { printf $$2 " " }'); do \
		cp $(swiftlibdir)/$$lib $(outdir)/Frameworks; \
	done
endef
#^ my guess is that Swift will eventually become a system framework when Apple starts using it to build iOS/OSX system apps ...
# yup, Swift 2.0 2015Q4 ~ 2016Q1

#$(outdir)/exec/%: libdirs += -L $(swiftlibdir)
$(outdir)/exec/%: $(outdir)/obj/%.o | $(outdir)/exec $(outdir)/Frameworks
	# grab the .d's of $^ and build any used modules ....
	$(clang) $(libdirs) $(os_frameworks) $(frameworks) -L $(swiftlibdir) -Wl,-rpath,@loader_path/../Frameworks -o $@ $^
	$(bundle_libswift)

# this is for standalone utility/helper programs, use module/main.swift for Application starters
$(outdir)/exec/%: execs/$(platform)/%.swift | $(outdir)/exec
	$(swiftc) $(debug) $(os_frameworks) $(frameworks) $(incdirs) $(libdirs) $(linklibs) \
		-Xlinker -rpath -Xlinker @loader_path/../Frameworks \
		-module-name $*.MainExec \
		-emit-executable -o $@ \
		$(filter %.swift,$+)

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
	mkdir $(dir $@)/lib$*; cd $(dir $@)/lib$*; for i in $(realpath $^); do \
		$(clang) -ObjC -c $(os_frameworks) $(frameworks) $(incdirs) $(libdirs) $(linklibs) $$i; \
	done;
	libtool -static -o $@ $(patsubst %.m,$(dir $@)/lib$*/%.o,$(notdir $^))

$(outdir)/libswift%.a: $(outdir)/obj/lib%.a
	lipo -output $@ -create $^

.PRECIOUS: $(outdir)/Frameworks/lib%.dylib $(outdir)/obj/%.o $(outdir)/exec/% $(outdir)/%.swiftmodule $(outdir)/%.swiftdoc
.PHONY: submake_% $(outdir)/Frameworks/libswift%.dylib
.LIBPATTERNS: lib%.dylib lib%.a
MAKEFLAGS += --no-builtin-rules
