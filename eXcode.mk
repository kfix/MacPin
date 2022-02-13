# Makefile.eXcode: helpers for using Swift & Xcode tooling

# import this near the top of your Makefile, only input variable is $builddir

eXcode := $(lastword $(MAKEFILE_LIST))

########################
#installed_sdks		!= xcodebuild -showsdks | awk '$NF > 1 && $(NF-1)=="-sdk" {printf $NF " "}'
platforms			?= macos ios
platform			?= macos

sdks				?= macosx iphoneos iphonesimulator
sdks_macos			?= macosx
sdks_ios			?= iphoneos iphonesimulator
sdk					?= macosx

archs_macosx		?= x86_64 arm64
archs_iphonesimulator	?= $(archs_macosx)
archs_iphoneos		?= arm64
arch				?= $(shell uname -m)

target_ver_macos	?= 11.6
# can we get the running version, if not pre-set?
target_macos		?= apple-macosx$(target_ver_macos)
target_ver_ios		?= 13.0
target_ios			?= apple-ios$(target_ver_ios)
target				?= $(target_macos)

ifeq (sim,$(only))
$(info Only building for iOS Simulator)
sdk := iphonesimulator
platform := ios
target := $(target_ios)
endif

outdir				:= $(builddir)/$(sdk)-$(arch)-$(target_$(platform))
outdir_mac			:= $(builddir)/macosx-$(arch)-$(target_macos)
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

debug				?=
verbose				?=

###################
# swift scaffolding
###################
# https://github.com/apple/swift-driver
ifeq (1,$(CLTOOLS))
sdkpath				:= /$(shell pkgutil --volume / --only-dirs --files com.apple.pkg.CLTools_SDK_macOS110 | grep -m1 MacOSX11.3.sdk$$)
swiftc				:= /$(shell pkgutil --volume / --only-dirs --files com.apple.pkg.CLTools_Executables | grep -m1 usr/bin$$)/swiftc -sdk $(sdk) -target $(arch)-$(target_$(platform)) $(verbose)
swiftbuildbin		:= /$(patsubst %-build,%,$(shell pkgutil --volume / --only-files --files com.apple.pkg.CLTools_Executables | grep -m1 bin/swift-build$$))
### XXX: appears CLTools doesn't ship SPM libraries yet, so Package.swift can't be compiled
else
sdkpath				:= $(shell xcrun --show-sdk-path --sdk $(sdk))
swiftc				:= xcrun -sdk $(sdk) swiftc -target $(arch)-$(target_$(platform)) $(verbose)
swiftbuildbin		:= $(shell command -v swift)
endif

########################
# SPM configuration
########################
swiftbuild			:= $(swiftbuildbin) build --configuration release \
	--build-path $(outdir)/swiftpm \
	-Xswiftc "-sdk" -Xswiftc $(sdkpath) \
	-Xswiftc "-target" -Xswiftc $(arch)-$(target_$(platform))

swiftrun_mac		:= $(swiftbuildbin) run --configuration release \
	--build-path $(outdir_mac)/swiftpm

spm_build := $(shell $(swiftbuild) --show-bin-path)

$(info [$(eXcode)] $$(swiftbuild) := $(swiftbuild))
$(info [$(eXcode)] $$(spm_build) := $(spm_build))
