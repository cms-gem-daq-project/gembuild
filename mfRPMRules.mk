# Created with insights from
## amc13/config/mfRPMRules.mk
## xdaq/config/mfRPM.rules
## xdaq/config/mfBuildRPM.rules
## xdaq/config/mfSetupRPM.rules
## xdaq/config/mfExternRPM.rules

RPMBUILD_DIR=$(PackagePath)/rpm

ifndef BUILD_COMPILER
BASE_COMPILER=$(subst -,_,$(CC))
BUILD_COMPILER :=$(BASE_COMPILER)$(shell $(CC) -dumpversion | sed -e 's/\./_/g')
endif

ifndef PACKAGE_FULL_RELEASE
# would like to use the correct %?{dist}
PACKAGE_FULL_RELEASE = $(BUILD_VERSION).$(GITREV)git.$(GEM_OS).$(BUILD_COMPILER)
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

RPM_OPTIONS=
ifeq ($(Arch),arm)
    RPM_OPTIONS=--define "_binary_payload 1"
endif

.PHONY: rpm _rpmall
rpm: _rpmall
_rpmall: _all _spec_update _rpmbuild

.PHONY: _rpmbuild _rpmprep
_rpmbuild: _spec_update _rpmprep
	@mkdir -p $(RPMBUILD_DIR)/RPMBUILD/{RPMS/{arm,noarch,i586,i686,x86_64},SPECS,BUILD,SOURCES,SRPMS}
	rpmbuild --quiet -ba -bl \
    --define "_requires $(REQUIRES_LIST)" \
    --define "_build_requires $(BUILD_REQUIRES_LIST)" \
    --define  "_topdir $(PWD)/rpm/RPMBUILD" $(RPMBUILD_DIR)/$(PackageName).spec \
    $(RPM_OPTIONS) --target "$(Arch)"
	find  $(RPMBUILD_DIR)/RPMBUILD -name "*.rpm" -exec mv {} $(RPMBUILD_DIR) \;

.PHONY: _spec_update
_spec_update:
	@mkdir -p $(RPMBUILD_DIR)
	if [ -e $(PackagePath)/spec.template ]; then \
		echo $(PackagePath) found spec.template; \
		cp $(PackagePath)/spec.template $(RPMBUILD_DIR)/$(PackageName).spec; \
	elif [ -e $(BUILD_HOME)/$(Project)/config/specTemplate.spec ]; then \
		echo  $(BUILD_HOME)/$(Project)/config/specTemplate.spec found; \
		cp $(BUILD_HOME)/$(Project)/config/specTemplate.spec $(RPMBUILD_DIR)/$(PackageName).spec; \
	else \
		echo No valid spec template found; \
		exit 2; \
	fi

	sed -i 's#__gitrev__#$(GITREV)#'                                   $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__builddate__#$(BUILD_DATE)#'                            $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__package__#$(Package)#'                                 $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__packagename__#$(PackageName)#'                         $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__version__#$(PACKAGE_FULL_VERSION)#'                    $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__release__#$(PACKAGE_FULL_RELEASE)#'                    $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__prefix__#$(INSTALL_PREFIX)#'                           $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__sources_dir__#$(RPMBUILD_DIR)/RPMBUILD/SOURCES#'       $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__packagedir__#$(PackagePath)#'                          $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__os__#$(GEM_OS)#'                                       $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__platform__#$(GEM_PLATFORM)#'                           $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__project__#$(Project)#'                                 $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__author__#$(Packager)#'                                 $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__summary__#None#'                                       $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__description__#None#'                                   $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__url__#None#'                                           $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__buildarch__#$(Arch)#'                                  $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__requires_list__#$(REQUIRED_PACKAGE_LIST)#'             $(RPMBUILD_DIR)/$(PackageName).spec
	sed -i 's#__build_requires_list__#$(BUILD_REQUIRED_PACKAGE_LIST)#' $(RPMBUILD_DIR)/$(PackageName).spec

	if [ -e $(PackagePath)/scripts/postinstall.sh ]; then \
		sed -i '\#\bpost\b#r $(PackagePath)/scripts/postinstall.sh' $(RPMBUILD_DIR)/$(PackageName).spec; \
	    sed -i 's#__prefix__#$(INSTALL_PREFIX)#' $(RPMBUILD_DIR)/$(PackageName).spec; \
	fi


.PHONY: cleanrpm _cleanrpm
cleanrpm: _cleanrpm
_cleanrpm:
	-rm -rf $(RPMBUILD_DIR)
