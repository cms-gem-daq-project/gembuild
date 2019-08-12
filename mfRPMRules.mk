# Created with insights from
## amc13/config/mfRPMRules.mk
## xdaq/config/mfRPM.rules
## xdaq/config/mfBuildRPM.rules
## xdaq/config/mfSetupRPM.rules
## xdaq/config/mfExternRPM.rules

ProjectPath?=$(BUILD_HOME)/$(Project)
PackagePath?=$(ProjectPath)
RPM_DIR:=$(PackagePath)/rpm
RPMBUILD_DIR:=$(RPM_DIR)/RPMBUILD

ifndef BUILD_COMPILER
BASE_COMPILER  =$(word 1, $(shell $(CC) --version))
BASE_COMPILER :=$(subst -,_,$(BASE_COMPILER))
BUILD_COMPILER:=$(BASE_COMPILER)$(shell $(CC) -dumpfullversion -dumpversion | sed -e 's/\./_/g')
endif

ifndef PACKAGE_FULL_RELEASE
# would like to use the correct %?{dist}
PACKAGE_FULL_RELEASE=$(BUILD_VERSION).$(GITREV)git.$(GEM_OS).$(BUILD_COMPILER)
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

.PHONY: rpm rpmprep
## @rpm performs all steps necessary to generate RPM packages
rpm: _spec_update _rpmbuild _rpmharvest

## @rpm Perform any specific setup before packaging, is an implicit dependency of `rpm`
rpmprep:

.PHONY: _rpmbuild _rpmharvest
_rpmbuild: all _spec_update rpmprep
	$(MakeDir) $(RPMBUILD_DIR)/{RPMS/{arm,noarch,i586,i686,x86_64},SPECS,BUILD,SOURCES,SRPMS}
	rpmbuild --quiet -ba -bl \
	    --buildroot=$(RPMBUILD_DIR)/BUILDROOT \
	    --define "_requires $(REQUIRES_LIST)" \
	    --define "_build_requires $(BUILD_REQUIRES_LIST)" \
	    --define  "_topdir $(RPMBUILD_DIR)" \
	    $(RPM_DIR)/$(PackageName).spec \
	    $(RPM_OPTIONS) --target "$(Arch)"

_rpmharvest: _rpmbuild
	find  $(RPMBUILD_DIR) -name "*.rpm" -exec mv {} $(RPM_DIR)/ \;

.PHONY: _spec_update
_spec_update:
	$(MakeDir) $(RPMBUILD_DIR)
	if [ -e $(PackagePath)/spec.template ]; then \
	    echo "$(PackagePath) found spec.template"; \
	    echo "cp $(PackagePath)/spec.template $(RPM_DIR)/$(PackageName).spec"; \
	    cp $(PackagePath)/spec.template $(RPM_DIR)/$(PackageName).spec; \
	elif [ -e $(ProjectPath)/config/specTemplate.spec ]; then \
	    echo "$(ProjectPath)/config/specTemplate.spec found"; \
	    echo "cp $(ProjectPath)/config/specTemplate.spec $(RPM_DIR)/$(PackageName).spec"; \
	    cp $(ProjectPath)/config/specTemplate.spec $(RPM_DIR)/$(PackageName).spec; \
	else \
	    echo "No valid spec template found"; \
	    exit 2; \
	fi

	sed -i 's#__gitrev__#$(GITREV)#'                                   $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__builddate__#$(BUILD_DATE)#'                            $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__package__#$(Package)#'                                 $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__longpackage__#$(LongPackage)#'                         $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__packagename__#$(PackageName)#'                         $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__version__#$(PACKAGE_FULL_VERSION)#'                    $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__release__#$(PACKAGE_FULL_RELEASE)#'                    $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__prefix__#$(INSTALL_PATH)#'                             $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__sources_dir__#$(RPMBUILD_DIR)/SOURCES#'                $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__packagedir__#$(PackagePath)#'                          $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__os__#$(GEM_OS)#'                                       $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__platform__#$(GEM_PLATFORM)#'                           $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__project__#$(Project)#'                                 $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__author__#$(Packager)#'                                 $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__summary__#None#'                                       $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__description__#None#'                                   $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__url__#None#'                                           $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__buildarch__#$(Arch)#'                                  $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__requires_list__#$(REQUIRED_PACKAGE_LIST)#'             $(RPM_DIR)/$(PackageName).spec
	sed -i 's#__build_requires_list__#$(BUILD_REQUIRED_PACKAGE_LIST)#' $(RPM_DIR)/$(PackageName).spec

#	@if [ "${BuildDebuginfoRPM}" == "1" ]; then \
#	    echo "sed -i '1 i\%define _build_debuginfo_package %{nil}' $(RPM_DIR)/$(PackageName).spec"; \
#	    sed -i '1 i\%define _build_debuginfo_package %{nil}' $(RPM_DIR)/$(PackageName).spec; \
#	fi

	@if [ -e $(PackagePath)/scripts/postinstall.sh ]; then \
	    echo "sed -i '\#\bpost\b#r $(PackagePath)/scripts/postinstall.sh' $(RPM_DIR)/$(PackageName).spec"; \
	    sed -i '\#\bpost\b#r $(PackagePath)/scripts/postinstall.sh' $(RPM_DIR)/$(PackageName).spec; \
	    echo "sed -i 's#__prefix__#$(INSTALL_PATH)#' $(RPM_DIR)/$(PackageName).spec"; \
	    sed -i 's#__prefix__#$(INSTALL_PATH)#' $(RPM_DIR)/$(PackageName).spec; \
	fi


.PHONY: cleanrpm cleanallrpm
## @rpm Clean up the rpm build directory
cleanrpm:
	$(RM) $(RPMBUILD_DIR)

## @rpm Entirely remove the rpm directory
cleanallrpm: cleanrpm
	$(RM) $(RPM_DIR)
