BUILD_HOME?=$(shell dirname `pwd`)
$(info Using BUILD_HOME=$(BUILD_HOME))

INSTALL_PATH=/opt/$(Project)

CMSGEMOS_ROOT?=/opt/cmsgemos
CACTUS_ROOT?=/opt/cactus
XDAQ_ROOT?=/opt/xdaq
XHAL_ROOT?=/opt/xhal

GEM_PLATFORM := $(shell python -c "import platform; print(platform.platform())")
GEM_ARCH     := $(shell uname -m)
GEM_OS       := "unknown.os"

GIT_VERSION  := $(shell git describe --dirty --always --tags)
GEMDEVELOPER := $(shell id --user --name)
GITREV       := $(shell git rev-parse --short HEAD)
BUILD_DATE   := $(shell date -u +"%d%m%Y")

UNAME=$(strip $(shell uname -s))
ifeq ($(UNAME),Linux)
    ifneq ($(findstring redhat-5,$(GEM_PLATFORM)),)
        GEM_OS=slc5
    else ifneq ($(findstring redhat-6,$(GEM_PLATFORM)),)
        GEM_OS=slc6
    else ifneq ($(findstring centos-6,$(GEM_PLATFORM)),)
        GEM_OS=centos6
    else ifneq ($(findstring centos-7,$(GEM_PLATFORM)),)
        GEM_OS=centos7
    else ifneq ($(findstring centos-8,$(GEM_PLATFORM)),)
        GEM_OS=centos8
    else ifneq ($(findstring fedora-26,$(GEM_PLATFORM)),)
        GEM_OS=fedora26
    else ifneq ($(findstring fedora-27,$(GEM_PLATFORM)),)
        GEM_OS=fedora27
    else ifneq ($(findstring fedora-28,$(GEM_PLATFORM)),)
        GEM_OS=fedora28
    endif
endif
ifeq ($(UNAME),Darwin)
    GEM_OS=osx
endif

$(info OS Detected: $(GEM_OS))

# Tools
MakeDir=mkdir -p
RM=rm -rf

# Version variables from Makefile and ShortPackage
ShortPackageLoc:=$(shell echo "$(ShortPackage)" | tr '[:lower:]' '[:upper:]')
PACKAGE_VER_MAJOR?=$($(ShortPackageLoc)_VER_MAJOR)
PACKAGE_VER_MINOR?=$($(ShortPackageLoc)_VER_MINOR)
PACKAGE_VER_PATCH?=$($(ShortPackageLoc)_VER_PATCH)

ProjectPath?=$(BUILD_HOME)/$(Project)
PackagePath?=$(ProjectPath)
ConfigDir?=$(ProjectPath)/config

BUILD_VERSION?=$(shell $(ConfigDir)/tag2rel.sh | awk '{split($$0,a," "); print a[4];}' | awk '{split($$0,b,":"); print b[2];}')
PREREL_VERSION?=$(shell $(ConfigDir)/tag2rel.sh | awk '{split($$0,a," "); print a[8];}' | awk '{split($$0,b,":"); print b[2];}' )

$(info BUILD_VERSION $(BUILD_VERSION))
$(info PREREL_VERSION $(PREREL_VERSION))

CXX=g++
CC=gcc

LDFLAGS=-g

OPTFLAGS?=-g -O2

PACKAGE_FULL_VERSION?=$(PACKAGE_VER_MAJOR).$(PACKAGE_VER_MINOR).$(PACKAGE_VER_PATCH)
PACKAGE_ABI_VERSION?=$(PACKAGE_VER_MAJOR).$(PACKAGE_VER_MINOR)
PACKAGE_NOARCH_RELEASE?=$(BUILD_VERSION).$(GITREV)git

PackageSourceDir    ?= $(PackagePath)/src
PackageTestSourceDir?= $(PackagePath)/test
PackageIncludeDir   ?= $(PackagePath)/include
PackageLibraryDir   ?= $(PackagePath)/lib
PackageExecDir      ?= $(PackagePath)/bin
PackageObjectDir    ?= $(PackageSourceDir)/linux/$(Arch)
PackageDocsDir      ?= $(PackagePath)/doc/_build/html

# Set up SONAME for library generation rule
UseSONAMEs?=yes
ifeq ("$(UseSONAMEs)","yes")
    $(info UseSONAMEs is $(UseSONAMEs), SONAME in libraries)
    LibrarySONAME=$(@F).$(PACKAGE_ABI_VERSION)
    LibraryFull=$(@F).$(PACKAGE_FULL_VERSION)
    LibraryLink=$(@F)
    LDFLAGS_SONAME?=-Wl,-soname,$(LibrarySONAME)
    LDFLAGS+=$(LDFLAGS_SONAME)
else
    $(info UseSONAMEs is $(UseSONAMEs), no SONAME in libraries)
    LibrarySONAME=$(@F)
    LibraryFull=$(@F)
endif

define link-sonames =
$(info LibrarySONAME for $(@F) is $(LibrarySONAME))
@if [ "$(UseSONAMEs)" = "yes" ]; \
then \
    echo Symlinking for SONAMEs; \
    ln -sf $(LibraryFull) $(PackageLibraryDir)/$(LibrarySONAME); \
    ln -sf $(LibrarySONAME) $(PackageLibraryDir)/$(LibraryLink); \
else \
    echo Not symlinking for SONAMEs; \
fi
endef

define print-prereqs =
$(info Running $@ target)
$(info Target $@ has prereqs $?)
$(info Target $@ has outdated prereqs $^)
$(info Target $@ has order-only prereqs $|)
endef

.PHONY: all build clean cleanall default doc install uninstall release

## @common default target, no dependencies
default:

## @common clean compiled objects, override with steps to remove build objects
clean:

## @common clean everything (objects, docs, packages)
cleanall: clean cleandoc cleanallrpm

## @common build package, override with how to compile your package
build:

## @common build documentation, override with how to generate the documentation for your package
doc:

## @common Run all necessary steps to build complete package
all: build

# Install should fail if the required variables are not set:
ifeq ($(and $(PackageLibraryDir),$(PackageIncludeDir),$(PackageExecDir),$(PackageSourceDir)),)
install build: fail
fail:
	@echo "build and install require that certain arguments are set"
	@echo "ThisIsAnEmptyVariable is $(ThisIsAnEmptyVariable)"
	@echo "PackageLibraryDir is $(PackageLibraryDir)"
	@echo "PackageIncludeDir is $(PackageIncludeDir)"
	@echo "PackageExecDir is $(PackageExecDir)"
	@echo "PackageSourceDir is $(PackageSourceDir)"
	@echo "Unable to run target due to unset variables"
	@exit 2
else
## @common install library and binary package to `INSTALL_PREFIX`
install: all
	echo "Executing install step"
	$(MakeDir) $(INSTALL_PREFIX)$(INSTALL_PATH)/{bin,etc,include,lib,scripts}
	if [ -d $(PackageLibraryDir) ]; then \
	   cd $(PackageLibraryDir); \
	   find . -type f -exec sh -ec 'install -D -m 755 $$0 $(INSTALL_PREFIX)$(INSTALL_PATH)/lib/$$0' {} \; ; \
	   find . -type l -exec sh -ec 'if [ -n "$${0}" ]; then ln -sf $$(basename $$(readlink $$0)) $(INSTALL_PREFIX)$(INSTALL_PATH)/lib/$${0##./}; fi' {} \; ; \
	fi

	if [ -d $(PackageIncludeDir) ]; then \
	   cd $(PackageIncludeDir); \
	   find . \( -name "*.h" -o -name "*.hh" -o -name "*.hpp" -o -name "*.hxx" \) \
		-exec install -D -m 655 {} $(INSTALL_PREFIX)$(INSTALL_PATH)/include/{} \; ; \
	fi

	if [ -d $(PackageExecDir) ]; then \
	   cd $(PackageExecDir); \
	   find . -name "*" -exec install -D -m 755 {} $(INSTALL_PREFIX)$(INSTALL_PATH)/bin/{} \; ; \
	fi

	if [ -d $(PackagePath)/etc ]; then \
	   cd $(PackagePath)/etc; \
	   find . -name "*" -exec install -D -m 644 {} $(INSTALL_PREFIX)$(INSTALL_PATH)/etc/{} \; ; \
	fi

	if [ -d $(PackagePath)/scripts ]; then \
	   cd $(PackagePath)/scripts; \
	   find . -name "*" -exec install -D -m 755 {} $(INSTALL_PREFIX)$(INSTALL_PATH)/scripts/{} \; ; \
	fi

	$(MakeDir) $(INSTALL_PREFIX)/usr/lib/debug$(INSTALL_PATH)/{bin,lib}
	$(MakeDir) $(INSTALL_PREFIX)/usr/src/debug/$(Package)-$(PACKAGE_FULL_VERSION)

	if [ -d $(PackageSourceDir) ]; then \
	   cd $(PackageSourceDir); \
	   find . \( -name "*.cc"  -o -name "*.cpp" -o -name "*.cxx" -o -name "*.c" -o -name "*.C" \) \
		-exec install -D -m 655 {} $(INSTALL_PREFIX)/usr/src/debug/$(Package)-$(PACKAGE_FULL_VERSION)/src/{} \; ; \
	fi

	touch MAINTAINER.md CHANGELOG.md README.md LICENSE
endif

## @common uninstall package from `INSTALL_PREFIX`
uninstall:
	$(RM) $(INSTALL_PREFIX)$(INSTALL_PATH)/{bin,etc,include,lib,scripts}
	$(RM) $(INSTALL_PREFIX)/usr/lib/debug$(INSTALL_PATH)/{bin,lib}
	$(RM) $(INSTALL_PREFIX)/usr/src/debug/$(Package)-$(PACKAGE_FULL_VERSION)
	$(RM) $(INSTALL_PREFIX)$(INSTALL_PATH)/share/doc/$(Package)-$(PACKAGE_FULL_VERSION)
#	$(RM) $(INSTALL_PREFIX)$(INSTALL_PATH)

## @common run abi-compliance-checker against two commits (run only during MRs)
checkabi:
	$(ConfigDir)/ci/parse_api_changes.sh

# want this to *only* run if necessary
## @common prepare generated packages for a release
release: rpm doc
	$(MakeDir) $(ProjectPath)/release/api
	-rsync -ahcX --progress --partial $(RPM_DIR)/repos $(ProjectPath)/release/
	-if [ -d $(PackageDocsDir) ]; then rsync -ahcX --progress --partial $(PackageDocsDir)/ $(ProjectPath)/release/api/$(PackageName)/; fi

# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
RED    := $(shell tput -Txterm setaf 5)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

# ideas from https://gist.github.com/prwhite/8168133
## Show help
help: | help-prefix help-targets

help-prefix:
	@echo 'Usage:'
	@echo '  $(GREEN)make$(RESET) $(YELLOW)<target>$(RESET)'
	@echo '  $(GREEN)make$(RESET) $(YELLOW)<target>$(RESET) $(BLUE)<VAR>$(RESET)=$(RED)<value>$(RESET)'
	@echo ''

# --- helper

HELP_TARGET_MAX_CHAR_NUM = 20
help-targets:
	@awk '/^[a-zA-Z\-\_0-9]+:/ \
		{ \
			helpMessage = match(lastLine, /^## (.*)/); \
			if (helpMessage) { \
				helpCommand = substr($$1, 0, index($$1, ":")-1); \
				helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
				helpGroup = match(helpMessage, /^@([^ ]*)/); \
				if (helpGroup) { \
					helpGroup = substr(helpMessage, RSTART + 1, index(helpMessage, " ")-2); \
					helpMessage = substr(helpMessage, index(helpMessage, " ")+1); \
				} \
				printf "%s|  $(YELLOW)%-$(HELP_TARGET_MAX_CHAR_NUM)s$(RESET) %s\n", \
					helpGroup, helpCommand, helpMessage; \
			} \
		} \
		{ lastLine = $$0 }' \
		$(MAKEFILE_LIST) \
	| sort -t'|' -sk1,1 \
	| awk -F '|' ' \
			{ \
			cat = $$1; \
			if (cat != lastCat || lastCat == "") { \
				if ( cat == "0" ) { \
					print "Targets:" \
				} else { \
					gsub("_", " ", cat); \
					printf "\nTargets for %s:\n", cat; \
				} \
			} \
			print $$2 \
		} \
		{ lastCat = $$1 }'
