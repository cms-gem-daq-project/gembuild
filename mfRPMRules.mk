# Created with insights from
## amc13/config/mfRPMRules.mk
## xdaq/config/mfRPM.rules
## xdaq/config/mfBuildRPM.rules
## xdaq/config/mfSetupRPM.rules
## xdaq/config/mfExternRPM.rules

RPMBUILD_DIR=${PackagePath}/rpm/RPMBUILD

ifndef BUILD_COMPILER
BASE_COMPILER=$(subst -,_,$(CC))
BUILD_COMPILER :=$(BASE_COMPILER)$(shell $(CC) -dumpversion | sed -e 's/\./_/g')
endif

ifndef PACKAGE_FULL_RELEASE
# would like to use the correct %?{dist}
PACKAGE_FULL_RELEASE = $(BUILD_VERSION).$(GITREV)git.$(CMSGEMOS_OS).$(BUILD_COMPILER)
endif

ifndef REQUIRED_PACKAGE_LIST
REQUIRED_PACKAGE_LIST=$(shell awk 'BEGIN{IGNORECASE=1} /define $(PackageName)_REQUIRED_PACKAGE_LIST/ {print $$3;}' $(PackagePath)/include/packageinfo.h)
endif

ifndef BUILD_REQUIRED_PACKAGE_LIST
BUILD_REQUIRED_PACKAGE_LIST=$(shell awk 'BEGIN{IGNORECASE=1} /define $(PackageName)_BUILD_REQUIRED_PACKAGE_LIST/ {print $$3;}' $(PackagePath)/include/packageinfo.h)
endif

REQUIRES_LIST=0
ifndef REQUIRED_PACKAGE_LIST
REQUIRES_LIST=1
endif

BUILD_REQUIRES_LIST=0
ifndef BUILD_REQUIRED_PACKAGE_LIST
BUILD_REQUIRES_LIST=1
endif

IS_ARM=0
RPM_OPTIONS=
ifeq ($(Arch),arm)
    RPM_OPTIONS=--define "_binary_payload 1"
	IS_ARM=1
endif

.PHONY: rpm _rpmall
rpm: _rpmall
_rpmall: _all _spec_update _rpmbuild

.PHONY: _rpmbuild _rpmprep
_rpmbuild: _spec_update _rpmprep
	@mkdir -p ${RPMBUILD_DIR}/{RPMS/{arm,noarch,i586,i686,x86_64},SPECS,BUILD,SOURCES,SRPMS}
	rpmbuild --quiet -ba -bl \
    --define "_requires $(REQUIRES_LIST)" \
    --define "_build_requires $(BUILD_REQUIRES_LIST)" \
    --define  "_topdir $(PWD)/rpm/RPMBUILD" $(PackagePath)/rpm/$(PackageName).spec \
    $(RPM_OPTIONS) --target "$(Arch)"
	find  $(PackagePath)/rpm/RPMBUILD -name "*.rpm" -exec mv {} $(PackagePath)/rpm \;

.PHONY: _spec_update
_spec_update:
	@mkdir -p $(PackagePath)/rpm
	if [ -e $(PackagePath)/spec.template ]; then \
		echo $(PackagePath) found spec.template; \
		cp $(PackagePath)/spec.template $(PackagePath)/rpm/$(PackageName).spec; \
	elif [ -e $(BUILD_HOME)/$(Project)/config/specTemplate.spec ]; then \
		echo  $(BUILD_HOME)/$(Project)/config/specTemplate.spec found; \
		cp $(BUILD_HOME)/$(Project)/config/specTemplate.spec $(PackagePath)/rpm/$(PackageName).spec; \
	else \
		echo No valid spec template found; \
		exit 2; \
	fi

	sed -i 's#__gitrev__#$(GITREV)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__builddate__#$(BUILD_DATE)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__package__#$(Package)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__packagename__#$(PackageName)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__version__#$(PACKAGE_VER_MAJOR).$(PACKAGE_VER_MINOR).$(PACKAGE_VER_PATCH)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__release__#$(PACKAGE_FULL_RELEASE)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__prefix__#$(INSTALL_PREFIX)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__sources_dir__#$(RPMBUILD_DIR)/SOURCES#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__packagedir__#$(PackagePath)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__os__#$(CMSGEMOS_OS)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__platform__#None#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__project__#$(Project)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__author__#$(Packager)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__summary__#None#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__description__#None#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__url__#None#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__buildarch__#$(Arch)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__requires_list__#$(REQUIRED_PACKAGE_LIST)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__build_requires_list__#$(BUILD_REQUIRED_PACKAGE_LIST)#' $(PackagePath)/rpm/$(PackageName).spec
	sed -i 's#__is_arm__#$(IS_ARM)#' $(PackagePath)/rpm/$(PackageName).spec

	if [ -e $(PackagePath)/scripts/postinstall.sh ]; then \
		sed -i '\#\bpost\b#r $(PackagePath)/scripts/postinstall.sh' $(PackagePath)/rpm/$(PackageName).spec; \
	    sed -i 's#__prefix__#$(INSTALL_PREFIX)#' $(PackagePath)/rpm/$(PackageName).spec; \
	fi


.PHONY: cleanrpm _cleanrpm
cleanrpm: _cleanrpm
_cleanrpm:
	-rm -rf rpm
