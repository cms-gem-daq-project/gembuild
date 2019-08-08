BUILD_HOME ?= $(shell dirname `pwd`)
$(info Using BUILD_HOME=$(BUILD_HOME))

INSTALL_PREFIX?=/opt/$(Project)

# cmsgemos config. This section should be sourced from /opt/cmsgemos/config
CMSGEMOS_ROOT?=/opt/cmsgemos
CACTUS_ROOT?=/opt/cactus
XDAQ_ROOT?=/opt/xdaq

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
# end of cmsgemos config

# Tools
MakeDir=mkdir -p

## Version variables from Makefile and ShortPackage
ShortPackageLoc:=$(shell echo "$(ShortPackage)" | tr '[:lower:]' '[:upper:]')
PACKAGE_VER_MAJOR?=$($(ShortPackageLoc)_VER_MAJOR)
PACKAGE_VER_MINOR?=$($(ShortPackageLoc)_VER_MINOR)
PACKAGE_VER_PATCH?=$($(ShortPackageLoc)_VER_PATCH)

ConfigDir?=$(BUILD_HOME)/$(Project)/config

BUILD_VERSION?=$(shell $(ConfigDir)/tag2rel.sh | awk '{split($$0,a," "); print a[4];}' | awk '{split($$0,b,":"); print b[2];}')
PREREL_VERSION?=$(shell $(ConfigDir)/tag2rel.sh | awk '{split($$0,a," "); print a[8];}' | awk '{split($$0,b,":"); print b[2];}' )

$(info BUILD_VERSION $(BUILD_VERSION))
$(info PREREL_VERSION $(PREREL_VERSION))

CXX?=g++
CC?=gcc

PACKAGE_FULL_VERSION ?= $(PACKAGE_VER_MAJOR).$(PACKAGE_VER_MINOR).$(PACKAGE_VER_PATCH)
PACKAGE_NOARCH_RELEASE ?= $(BUILD_VERSION).$(GITREV)git

.PHONY: default all _all

default:
