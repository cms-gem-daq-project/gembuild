# Created with insights from
## amc13/config/mfPythonRPMRules.mk

ShortProject?=$(Project)
ProjectPath?=$(BUILD_HOME)/$(Project)
PackagePath?=$(ProjectPath)
RPM_DIR:=$(PackagePath)/rpm
RPMBUILD_DIR:=$(RPM_DIR)/build

ifndef PythonModules
$(error Python module names missing "PythonModules")
endif

TargetPIPName?=$(RPM_DIR)/$(PackageName).zip
TargetSRPMName?=$(RPM_DIR)/$(PackageName).src.rpm
TargetRPMName?=$(RPM_DIR)/$(PackageName).$(GEM_ARCH).rpm
PackageSetupFile?=$(RPMBUILD_DIR)/setup.py
PackagePrepFile?=$(PackageDir)/$(PackageName).prep

PackagingTargets=$(TargetPIPName)
PackagingTargets+=$(TargetSRPMName)
PackagingTargets+=$(TargetRPMName)

.PHONY: install-pip install-site uninstall-pip uninstall-site

## @python-common install the python pip package
install-pip: pip
ifneq ($(or $(RPM_DIR),$(PackageName),$(PACKAGE_FULL_VERSION),$(PREREL_VERSION)),)
	pip install $(RPM_DIR)/$(PackageName)-$(PACKAGE_FULL_VERSION)$(PREREL_VERSION).zip
else
	@echo "install-pip requires that certain arguments are set"
	@echo "RPM_DIR is $(RPM_DIR)"
	@echo "PackageName is $(PackageName)"
	@echo "PACKAGE_FULL_VERSION is $(PACKAGE_FULL_VERSION)"
	@echo "PREREL_VERSION is $(PREREL_VERSION)"
	@exit 2
#	$(error "Unable to run install-site due to unset variables")
endif

ifeq ($(and $(Namespace),$(ShortPackage),$(INSTALL_PREFIX),$(PYTHON_SITE_PREFIX),$(CMSGEMOS_ROOT)),)
install-site uninstall-site: fail-pyinstall
fail-pyinstall:
	@echo "install-site requires that certain arguments are set"
	@echo "Namespace is $(Namespace)"
	@echo "ShortPackage is $(ShortPackage)"
	@echo "INSTALL_PREFIX is $(INSTALL_PREFIX)"
	@echo "PYTHON_SITE_PREFIX is $(PYTHON_SITE_PREFIX)"
	@exit 2
#	$(error "Unable to run install-site due to unset variables")
endif

## @python-common install the python site-package
install: install-site
install-site: rpmprep
ifneq ($(Arch),arm)
	if [ -d pkg ]; then \
	   cd pkg; \
	   find $(Namespace) \( -type d -iname scripts \) -prune -o -type f \
	       -exec install -D -m 755 {} $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/{} \; ; \
	   cd $(Namespace)/scripts; \
	   find . -type f \
	       -exec install -D -m 755 {} $(INSTALL_PREFIX)$(INSTALL_PATH)/bin/$(ShortPackage)/{} \; ; \
	fi
endif

## @python-common uninstall the python pip package
uninstall: uninstall-site
uninstall-pip:
	pip uninstall $(PackageName)

## @python-common uninstall the python site-package
uninstall-site:
ifneq ($(Arch),arm)
	$(RM) $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/$(Namespace)/$(ShortPackage)
	$(RM) $(INSTALL_PREFIX)$(INSTALL_PATH)/bin/$(ShortPackage)
endif

.PHONY: pip rpm rpmprep
## @python-rpm Create a python package installable via pip
pip: _sdistbuild _pipharvest
## @python-rpm Create a python RPM package
rpm: _rpmbuild _rpmharvest
## @python-rpm Perform any specific setup before packaging, is a dependency of both `pip` and `rpm`
rpmprep: | $(PackagePrepFile)
# Copy the package skeleton
# Ensure the existence of the module directory
# Copy the libraries into python module
# Change directory into pkg and copy everything into rpm build dir
	cd pkg && \
	    find . -iname 'setup.*' -prune -o -name "*" -exec install -D \{\} $(RPMBUILD_DIR)/\{\} \;
# Add a manifest file (may not be necessary
#	echo "include */*.so" > $(RPMBUILD_DIR)/MANIFEST.in

.PHONY: _sdistbuild _bdistbuild
.PHONY: _pipharvest _rpmharvest _rpmbuild

_sdistbuild: $(PackagePrepFile) $(TargetPIPName)

_rpmbuild: $(PackagePrepFile) $(PackagingTargets)

$(TargetSRPMName): $(PackagePrepFile) $(PackageSetupFile) | rpmprep
	$(rpm-python-spec)
	rpmbuild --quiet -bs --clean \
	    --define "release $(PACKAGE_NOARCH_RELEASE)" \
	    --define "_binary_payload 1" \
	    --define "_topdir $(RPMBUILD_DIR)/$(GEM_ARCH)" \
	    $(RPMBUILD_DIR)/dist/$(PackageName).spec;
	touch $@

$(TargetRPMName): $(PackagePrepFile) $(PackageSetupFile) | rpmprep
	$(rpm-python-spec)
	rpmbuild --quiet -bb --clean \
	    --define "release $(PACKAGE_NOARCH_RELEASE).$(GEM_OS).python$(PYTHON_VERSION)" \
	    --define "_binary_payload 1" \
	    --define "_topdir $(RPMBUILD_DIR)/$(GEM_ARCH)" \
	    $(RPMBUILD_DIR)/dist/$(PackageName).spec
	rename $(PACKAGE_FULL_VERSION) $(PACKAGE_FULL_VERSION)_$(PACKAGE_NOARCH_RELEASE) $(RPMBUILD_DIR)/$(GEM_ARCH)/SOURCES/*$(PACKAGE_FULL_VERSION).tar.gz
	touch $@

$(TargetPIPName):  $(PackagePrepFile) $(PackageSetupFile) | rpmprep
	cd $(RPMBUILD_DIR) && python setup.py \
	    egg_info --tag-build=$(PREREL_VERSION) \
	    sdist --formats=bztar,gztar,zip
	touch $@

_rpmarm: all rpmprep
	cd $(RPMBUILD_DIR) && python setup.py sdist --formats=gztar \
	    bdist_rpm --quiet \
	    --release $(PACKAGE_NOARCH_RELEASE).peta_linux.python$(PYTHON_VERSION) \
	    --force-arch=$(GEM_ARCH) \
	    --spec-only
	mkdir -p $(RPMBUILD_DIR)/arm/SOURCES
	mv $(RPMBUILD_DIR)/dist/*.tar.gz $(RPMBUILD_DIR)/arm/SOURCES/
	rpmbuild --quiet -bb --clean \
	    --define "_binary_payload 1" \
	    --define "_topdir $(RPMBUILD_DIR)/arm" \
	    $(RPMBUILD_DIR)/dist/$(PackageName).spec

_bdistbuild: rpmprep
	cd $(RPMBUILD_DIR) && python setup.py \
	    egg_info --tag-build=$(PREREL_VERSION) \
	    bdist --formats=bztar,gztar,zip

_pipharvest: $(TargetPIPName)
	$(ProjectPath)/config/ci/generate_repo.sh $(GEM_OS) $(GEM_ARCH) $(RPM_DIR) $(RPMBUILD_DIR) $(ShortProject)

_rpmharvest: $(TargetSRPMName) $(TargetRPMName)
	$(ProjectPath)/config/ci/generate_repo.sh $(GEM_OS) $(GEM_ARCH) $(RPM_DIR) $(RPMBUILD_DIR) $(ShortProject)

$(PackageSetupFile): $(ProjectPath)/config/setupTemplate.py
	$(MakeDir) $(RPMBUILD_DIR)

	if [ -e $(PackagePath)/setup.py ]; then \
	    echo "Found $(PackagePath)/setup.py"; \
	    echo "$(PackagePath)/setup.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(PackagePath)/setup.py $(RPMBUILD_DIR)/setup.py; \
	elif [ -e $(PackagePath)/pkg/setup.py ]; then \
	    echo "Found $(PackagePath)/pkg/setup.py"; \
	    echo "$(PackagePath)/pkg/setup.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(PackagePath)/pkg/setup.py $(RPMBUILD_DIR)/setup.py; \
	elif [ -e $(ProjectPath)/config/setupTemplate.py ]; then \
	    echo "Found $(ProjectPath)/config/setupTemplate.py"; \
	    echo "$(ProjectPath)/config/setupTemplate.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(ProjectPath)/config/setupTemplate.py $(RPMBUILD_DIR)/setup.py; \
	else \
	    echo "Unable to find any setupTemplate.py"; \
	    exit 2; \
	fi

	sed -i 's#__author__#$(Packager)#'                $(RPMBUILD_DIR)/setup.py
	sed -i 's#__project__#$(Project)#'                $(RPMBUILD_DIR)/setup.py
	sed -i 's#__summary__#None#'                      $(RPMBUILD_DIR)/setup.py
	sed -i 's#__package__#$(Package)#'                $(RPMBUILD_DIR)/setup.py
	sed -i 's#__packagedir__#$(PackagePath)#'         $(RPMBUILD_DIR)/setup.py
	sed -i 's#__packagename__#$(PackageName)#'        $(RPMBUILD_DIR)/setup.py
	sed -i 's#__longpackage__#$(LongPackage)#'        $(RPMBUILD_DIR)/setup.py
	sed -i 's#__pythonmodules__#$(PythonModules)#'    $(RPMBUILD_DIR)/setup.py
	sed -i 's#__prefix__#$(GEMPYTHON_ROOT)#'          $(RPMBUILD_DIR)/setup.py
	sed -i 's#__os__#$(GEM_OS)#'                      $(RPMBUILD_DIR)/setup.py
	sed -i 's#__platform__#$(GEM_PLATFORM)#'          $(RPMBUILD_DIR)/setup.py
	sed -i 's#__description__#None#'                  $(RPMBUILD_DIR)/setup.py
	sed -i 's#___gitrev___#$(GITREV)#'                $(RPMBUILD_DIR)/setup.py
	sed -i 's#___gitver___#$(GIT_VERSION)#'           $(RPMBUILD_DIR)/setup.py
	sed -i 's#___version___#$(PACKAGE_FULL_VERSION)#' $(RPMBUILD_DIR)/setup.py
	sed -i 's#___buildtag___#$(PREREL_VERSION)#'      $(RPMBUILD_DIR)/setup.py
	sed -i 's#___release___#$(BUILD_VERSION)#'        $(RPMBUILD_DIR)/setup.py
	sed -i 's#___packager___#$(GEMDEVELOPER)#'        $(RPMBUILD_DIR)/setup.py
	sed -i 's#___builddate___#$(BUILD_DATE)#'         $(RPMBUILD_DIR)/setup.py

	if [ -e $(PackagePath)/setup.cfg ]; then \
	    echo "Found $(PackagePath)/setup.cfg"; \
	    echo "$(PackagePath)/setup.cfg $(RPMBUILD_DIR)/setup.cfg"; \
	    cp $(PackagePath)/setup.cfg $(RPMBUILD_DIR)/setup.cfg; \
	elif [ -e $(PackagePath)/pkg/setup.cfg ]; then \
	    echo "Found $(PackagePath)/pkg/setup.cfg"; \
	    echo "$(PackagePath)/pkg/setup.cfg $(RPMBUILD_DIR)/setup.cfg"; \
	    cp $(PackagePath)/pkg/setup.cfg $(RPMBUILD_DIR)/setup.cfg; \
	elif [ -e $(ProjectPath)/config/setupTemplate.cfg ]; then \
	    echo "Found $(ProjectPath)/config/setupTemplate.cfg"; \
	    echo "$(ProjectPath)/config/setupTemplate.cfg $(RPMBUILD_DIR)/setup.cfg"; \
	    cp $(ProjectPath)/config/setupTemplate.cfg $(RPMBUILD_DIR)/setup.cfg; \
	else \
	    echo "Unable to find any setupTemplate.cfg"; \
	    exit 2; \
	fi

	sed -i 's#__author__#$(Packager)#'                $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__project__#$(Project)#'                $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__summary__#None#'                      $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__package__#$(Package)#'                $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__packagedir__#$(PackagePath)#'         $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__packagename__#$(PackageName)#'        $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__longpackage__#$(LongPackage)#'        $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__pythonmodules__#$(PythonModules)#'    $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__prefix__#$(GEMPYTHON_ROOT)#'          $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__os__#$(GEM_OS)#'                      $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__platform__#$(GEM_PLATFORM)#'          $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#__description__#None#'                  $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#___gitrev___#$(GITREV)#'                $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#___gitver___#$(GIT_VERSION)#'           $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#___version___#$(PACKAGE_FULL_VERSION)#' $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#___buildtag___#$(PREREL_VERSION)#'      $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#___release___#$(BUILD_VERSION)#'        $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#___packager___#$(GEMDEVELOPER)#'        $(RPMBUILD_DIR)/setup.cfg
	sed -i 's#___builddate___#$(BUILD_DATE)#'         $(RPMBUILD_DIR)/setup.cfg

define rpm-python-spec =
cd $(RPMBUILD_DIR) && python setup.py \
    sdist --formats=bztar,gztar,zip \
    bdist_rpm --quiet \
    --force-arch=$(GEM_ARCH) \
    --spec-only;
mkdir -p $(RPMBUILD_DIR)/$(GEM_ARCH)/SOURCES;
mv $(RPMBUILD_DIR)/dist/*.tar.gz $(RPMBUILD_DIR)/$(GEM_ARCH)/SOURCES/;
sed -i '/%define release/d' $(RPMBUILD_DIR)/dist/$(PackageName).spec
endef

.PHONY: cleanrpm cleanallrpm
cleanrpm:
	$(RM) $(RPMBUILD_DIR)

cleanallrpm:
	$(RM) $(RPM_DIR)
