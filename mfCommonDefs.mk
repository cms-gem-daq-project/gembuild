BUILD_HOME?=$(shell dirname `pwd`)
$(info Using BUILD_HOME=$(BUILD_HOME))

INSTALL_PATH=/opt/$(Project)

CMSGEMOS_ROOT?=/opt/cmsgemos
CACTUS_ROOT?=/opt/cactus
XDAQ_ROOT?=/opt/xdaq
XHAL_ROOT?=/opt/xhal

GEM_PLATFORM := $(shell python -c "import platform; print(platform.platform())")
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

## Version variables from Makefile and ShortPackage
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

PACKAGE_FULL_VERSION ?= $(PACKAGE_VER_MAJOR).$(PACKAGE_VER_MINOR).$(PACKAGE_VER_PATCH)
PACKAGE_NOARCH_RELEASE ?= $(BUILD_VERSION).$(GITREV)git

PackageSourceDir    ?= $(PackagePath)/src
PackageTestSourceDir?= $(PackagePath)/test
PackageIncludeDir   ?= $(PackagePath)/include
PackageLibraryDir   ?= $(PackagePath)/lib
PackageExecDir      ?= $(PackagePath)/bin
PackageObjectDir    ?= $(PackageSourceDir)/linux/$(Arch)

.PHONY: default clean build all install uninstall

default:

clean:

build:

all: build

## Install should fail if the required variables are not set:
ifeq ($(and $(ThisIsAnEmptyVariable),$(PackageLibraryDir),$(PackageIncludeDir),$(PackageExecDir),$(PackageSourceDir)),)
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
install: all
	echo "Executing install step"
	$(MakeDir) $(INSTALL_PREFIX)$(INSTALL_PATH)/{bin,etc,include,lib,scripts}
	if [ -d $(PackagePath)/lib ]; then \
	   cd $(PackagePath)/lib; \
	   find . -name "*.so" -exec install -D -m 755 {} $(INSTALL_PREFIX)$(INSTALL_PATH)/lib/{} \; ; \
	fi
#	   find . -type l -exec sh -c 'ln -s -f ${INSTALL_PREFIX}$(INSTALL_PATH)/lib/$(basename $(readlink $0)) ${INSTALL_PREFIX}${INSTALL_PATH}/lib/$0' {} \;

	if [ -d $(PackagePath)/include ]; then \
	   cd $(PackagePath)/include; \
	   find . \( -name "*.h" -o -name "*.hh" -o -name "*.hpp" -o -name "*.hxx" \) \
		-exec install -D -m 655 {} $(INSTALL_PREFIX)$(INSTALL_PATH)/include/{} \; ; \
	fi

	if [ -d $(PackagePath)/bin ]; then \
	   cd $(PackagePath)/bin; \
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

	if [ -d $(PackagePath)/src ]; then \
	   cd $(PackagePath)/src; \
	   find . \( -name "*.cc"  -o -name "*.cpp" -o -name "*.cxx" -o -name "*.c" -o -name "*.C" \) \
		-exec install -D -m 655 {} $(INSTALL_PREFIX)/usr/src/debug/$(Package)-$(PACKAGE_FULL_VERSION)/src/{} \; ; \
	fi

	touch MAINTAINER.md CHANGELOG.md README.md LICENSE
endif

uninstall:
	$(RM) $(INSTALL_PREFIX)$(INSTALL_PATH)/{bin,etc,include,lib,scripts}
	$(RM) $(INSTALL_PREFIX)/usr/lib/debug$(INSTALL_PATH)/{bin,lib}
	$(RM) $(INSTALL_PREFIX)/usr/src/debug/$(Package)-$(PACKAGE_FULL_VERSION)
	$(RM) $(INSTALL_PREFIX)$(INSTALL_PATH)/share/doc/$(Package)-$(PACKAGE_FULL_VERSION)
#	$(RM) $(INSTALL_PREFIX)$(INSTALL_PATH)

## Unfortunately, only picks up the targets listed in the Makefile that was invoked
.PHONY: help
help:
	$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | \
	    awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | \
	    sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
