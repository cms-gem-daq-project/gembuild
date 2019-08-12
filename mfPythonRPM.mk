# Created with insights from
## amc13/config/mfPythonRPMRules.mk

ProjectPath?=$(BUILD_HOME)/$(Project)
PackagePath?=$(ProjectPath)
RPM_DIR:=$(PackagePath)/rpm
RPMBUILD_DIR:=$(RPM_DIR)/build

ifndef PACKAGE_FULL_RELEASE
PACKAGE_FULL_RELEASE?=$(PACKAGE_NOARCH_RELEASE).$(GEM_OS)
endif

ifndef PythonModules
$(error Python module names missing "PythonModules")
endif

.PHONY: pip rpm rpmprep
## @python-rpm Create a python package installable via pip
pip: _sdistbuild _harvest
## @python-rpm Create a python RPM package
rpm: _rpmbuild _harvest
## @python-rpm Perform any specific setup before packaging, is a dependency of both `pip` and `rpm`
rpmprep:

.PHONY: _sdistbuild _bdistbuild _sdistbuild
.PHONY: _harvest _setup_update _rpmbuild _rpmsetup

# Copy the package skeleton
# Ensure the existence of the module directory
# Copy the libraries into python module
_rpmsetup: rpmprep _setup_update
# Change directory into pkg and copy everything into rpm build dir
	@echo "Running _rpmsetup target"
	cd pkg && \
	    find . -iname 'setup.*' -prune -o -name "*" -exec install -D \{\} $(RPMBUILD_DIR)/\{\} \;
# Add a manifest file (may not be necessary
#	echo "include */*.so" > $(RPMBUILD_DIR)/MANIFEST.in

_rpmbuild: all _sdistbuild
	@echo "Running _rpmbuild target"
	cd $(RPMBUILD_DIR) && python setup.py bdist_rpm \
	    --release $(PACKAGE_NOARCH_RELEASE).$(GEM_OS).python$(PYTHON_VERSION) \
	    --force-arch=noarch

_rpmarm: all _rpmsetup
	@echo "Running _rpmarm target"
	cd $(RPMBUILD_DIR) && python setup.py sdist --formats=gztar \
	    bdist_rpm --quiet \
	    --release $(PACKAGE_NOARCH_RELEASE).peta_linux.python$(PYTHON_VERSION) \
	    --force-arch=noarch --spec-only
	mkdir -p $(RPMBUILD_DIR)/arm/SOURCES
	cp $(RPMBUILD_DIR)/dist/*.tar.gz $(RPMBUILD_DIR)/arm/SOURCES/
	rpmbuild --quiet -bb --clean \
	    --define "_binary_payload 1" \
	    --define "_topdir $(RPMBUILD_DIR)/arm" \
	    $(RPMBUILD_DIR)/dist/${PackageName}.spec

_bdistbuild: _rpmsetup
	@echo "Running _tarbuild target"
	cd $(RPMBUILD_DIR) && python setup.py \
	    egg_info --tag-build=$(PREREL_VERSION) \
	    bdist --formats=bztar,gztar,zip

_sdistbuild: _rpmsetup
	@echo "Running _tarbuild target"
	cd $(RPMBUILD_DIR) && python setup.py \
	    egg_info --tag-build=$(PREREL_VERSION) \
	    sdist --formats=bztar,gztar,zip

_harvest:
	find $(RPMBUILD_DIR)/dist \( -iname "*.tar.gz" \
	    -o -iname "*.tar.bz2" \
	    -o -iname "*.tgz" \
	    -o -iname "*.zip" \
	    -o -iname "*.tbz2" \) -print0 -exec mv -t $(RPM_DIR)/ {} \+
	-rename tar. t $(RPM_DIR)/*tar*

_setup_update:
	@echo "Running _setup_update target"
	$(MakeDir) $(RPMBUILD_DIR)

	if [ -e $(PackagePath)/setup.py ]; then \
	    echo "Found $(PackagePath)/setup.py"; \
	    echo "$(PackagePath)/setup.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(PackagePath)/setup.py $(RPMBUILD_DIR)/setup.py; \
	elif [ -e $(PackagePath)/pkg/setup.py ]; then \
	    echo "Found $(PackagePath)/pkg/setup.py"; \
	    echo "$(PackagePath)/pkg/setup.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(PackagePath)/pkg/setup.py $(RPMBUILD_DIR)/setup.py; \
	elif [ -e $(PackagePath)/setup/setup.py ]; then \
	    echo "Found $(PackagePath)/setup/setup.py"; \
	    echo "$(PackagePath)/setup/setup.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(PackagePath)/setup/setup.py $(RPMBUILD_DIR)/setup.py; \
	elif [ -e $(PackagePath)/setup/build/setup.py ]; then \
	    echo "Found $(PackagePath)/setup/build/setup.py"; \
	    echo "$(PackagePath)/setup/build/setup.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(PackagePath)/setup/build/setup.py $(RPMBUILD_DIR)/setup.py; \
	elif [ -e $(ProjectPath)/setup/config/setupTemplate.py ]; then \
	    echo "Found $(ProjectPath)/setup/config/setupTemplate.py"; \
	    echo "$(ProjectPath)/setup/config/setupTemplate.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(ProjectPath)/setup/config/setupTemplate.py $(RPMBUILD_DIR)/setup.py; \
	elif [ -e $(ProjectPath)/config/setupTemplate.py ]; then \
	    echo "Found $(ProjectPath)/config/setupTemplate.py"; \
	    echo "$(ProjectPath)/config/setupTemplate.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(ProjectPath)/config/setupTemplate.py $(RPMBUILD_DIR)/setup.py; \
	elif [ -e $(BUILD_HOME)/config/build/setupTemplate.py ]; then \
	    echo "Found $(BUILD_HOME)/config/build/setupTemplate.py"; \
	    echo "$(BUILD_HOME)/config/build/setupTemplate.py $(RPMBUILD_DIR)/setup.py"; \
	    cp $(BUILD_HOME)/config/build/setupTemplate.py $(RPMBUILD_DIR)/setup.py; \
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
	elif [ -e $(PackagePath)/setup/setup.cfg ]; then \
	    echo "Found $(PackagePath)/setup/setup.cfg"; \
	    echo "$(PackagePath)/setup.cfg $(RPMBUILD_DIR)/setup.cfg"; \
	    cp $(PackagePath)/setup/setup.cfg $(RPMBUILD_DIR)/setup.cfg; \
	elif [ -e $(PackagePath)/setup/build/setup.cfg ]; then \
	    echo "Found $(PackagePath)/setup/build/setup.cfg"; \
	    echo "$(PackagePath)/setup/build/setup.cfg $(RPMBUILD_DIR)/setup.cfg"; \
	    cp $(PackagePath)/setup/build/setup.cfg $(RPMBUILD_DIR)/setup.cfg; \
	elif [ -e $(ProjectPath)/setup/config/setupTemplate.cfg ]; then \
	    echo "Found $(ProjectPath)/setup/config/setupTemplate.cfg"; \
	    echo "$(ProjectPath)/setup/config/setupTemplate.cfg $(RPMBUILD_DIR)/setup.cfg"; \
	    cp $(ProjectPath)/setup/config/setupTemplate.cfg $(RPMBUILD_DIR)/setup.cfg; \
	elif [ -e $(ProjectPath)/config/setupTemplate.cfg ]; then \
	    echo "Found $(ProjectPath)/config/setupTemplate.cfg"; \
	    echo "$(ProjectPath)/config/setupTemplate.cfg $(RPMBUILD_DIR)/setup.cfg"; \
	    cp $(ProjectPath)/config/setupTemplate.cfg $(RPMBUILD_DIR)/setup.cfg; \
	elif [ -e $(BUILD_HOME)/config/build/setupTemplate.cfg ]; then \
	    echo "Found $(BUILD_HOME)/config/setupTemplate.cfg"; \
	    echo "$(BUILD_HOME)/config/build/setupTemplate.cfg $(RPMBUILD_DIR)/setup.cfg"; \
	    cp $(BUILD_HOME)/config/build/setupTemplate.cfg $(RPMBUILD_DIR)/setup.cfg; \
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


.PHONY: cleanrpm cleanallrpm
cleanrpm:
	$(RM) $(RPMBUILD_DIR)

cleanallrpm:
	$(RM) $(RPM_DIR)
