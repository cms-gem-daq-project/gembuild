PYVER?=python
## Python
PYTHON_VERSION        = $(shell $(PYVER) -c "import distutils.sysconfig;print(distutils.sysconfig.get_python_version())")
# PYTHON_VERSION        = $(shell $(PYVER) -c "import sys; sys.stdout.write(sys.version[:3])")
PYTHON_LIB            = python$(PYTHON_VERSION)
PYTHON_LIB_PREFIX     = $(shell $(PYVER) -c "from distutils.sysconfig import get_python_lib;import os.path;print(os.path.split(get_python_lib(standard_lib=True))[0])")
PYTHON_SITE_PREFIX    = $(shell $(PYVER) -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")
PYTHON_INCLUDE_PREFIX = $(shell $(PYVER) -c "import distutils.sysconfig;print(distutils.sysconfig.get_python_inc())")

# Python Config
PYTHONCFLAGS = $(shell pkg-config $(PYVER) --cflags)
PYTHONLIBS   = $(shell pkg-config $(PYVER) --libs)
PYTHONGLIBS  = $(shell pkg-config $(PYVER) --glibs)

IncludeDirs+=$(PYTHON_INCLUDE_PREFIX)

# DependentLibraries+=python$(PYTHON_VERSION)

# DynamicLinkFlags+=

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
	$(MakeDir) $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/$(Namespace)/$(ShortPackage)
	if [ -d pkg ]; then \
	   cd pkg; \
	   find $(Namespace) \( -type d -iname scripts \) -prune -o -type f \
	       -exec install -D -m 755 {} $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/{} \; ; \
	   cd $(Namespace)/scripts; \
	   find . -type f \
	       -exec install -D -m 755 {} $(INSTALL_PREFIX)$(CMSGEMOS_ROOT)/bin/$(ShortPackage)/{} \; ; \
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
	$(RM) $(INSTALL_PREFIX)$(CMSGEMOS_ROOT)/bin/$(ShortPackage)
endif
