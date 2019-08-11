## Python
PYTHON_VERSION        = $(shell python -c "import distutils.sysconfig;print(distutils.sysconfig.get_python_version())")
# PYTHON_VERSION        = $(shell python -c "import sys; sys.stdout.write(sys.version[:3])")
PYTHON_LIB            = python$(PYTHON_VERSION)
PYTHON_LIB_PREFIX     = $(shell python -c "from distutils.sysconfig import get_python_lib;import os.path;print(os.path.split(get_python_lib(standard_lib=True))[0])")
PYTHON_SITE_PREFIX    = $(shell python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")
PYTHON_INCLUDE_PREFIX = $(shell python -c "import distutils.sysconfig;print(distutils.sysconfig.get_python_inc())")

# Python Config
PYTHONCFLAGS = $(shell pkg-config python --cflags)
PYTHONLIBS   = $(shell pkg-config python --libs)
PYTHONGLIBS  = $(shell pkg-config python --glibs)

IncludeDirs+=$(PYTHON_INCLUDE_PREFIX)

# DependentLibraries+=python$(PYTHON_VERSION)

# DynamicLinkFlags+=

.PHONY: install-pip install-site uninstall-pip uninstall-site

install-pip: pip
ifneq ($(or $(ThisIsAnEmptyVariable),$(RPM_DIR),$(PackageName),$(PACKAGE_FULL_VERSION),$(PREREL_VERSION)),)
	pip install $(RPM_DIR)/$(PackageName)-$(PACKAGE_FULL_VERSION)$(PREREL_VERSION).zip
else
	@echo "install-pip require that certain arguments are set"
	@echo "ThisIsAnEmptyVariable is $(ThisIsAnEmptyVariable)"
	@echo "RPM_DIR is $(RPM_DIR)"
	@echo "PackageName is $(PackageName)"
	@echo "PACKAGE_FULL_VERSION is $(PACKAGE_FULL_VERSION)"
	@echo "PREREL_VERSION is $(PREREL_VERSION)"
	@exit 2
#	$(error "Unable to run install-site due to unset variables")
endif

ifeq ($(and $(ThisIsAnEmptyVariable),$(Namespace),$(ShortPackage),$(INSTALL_PREFIX),$(PYTHON_SITE_PREFIX)),)
install-site uninstall-site: fail-pyinstall
fail-pyinstall:
	@echo "install-site require that certain arguments are set"
	@echo "ThisIsAnEmptyVariable is $(ThisIsAnEmptyVariable)"
	@echo "Namespace is $(Namespace)"
	@echo "ShortPackage is $(ShortPackage)"
	@echo "INSTALL_PREFIX is $(INSTALL_PREFIX)"
	@echo "PYTHON_SITE_PREFIX is $(PYTHON_SITE_PREFIX)"
	@exit 2
#	$(error "Unable to run install-site due to unset variables")
endif

install-site: _rpmprep
ifneq ($(Arch),arm)
	$(MakeDir) $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/$(Namespace)/$(ShortPackage)
	@if [ -d pkg ]; then \
	   cd pkg; \
	   find $(Namespace) \( -type d -iname scripts \) -prune -o -type f \
	       -exec install -D -m 755 {} $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/{} \; ; \
	   find $(Namespace)/scripts -type f \
	       -exec install -D -m 755 {} $(INSTALL_PREFIX)$(CMSGEMOS_ROOT)/bin/$(ShortPackage)/{} \; ; \
	fi
endif

uninstall-pip:
	pip uninstall $(PackageName)

uninstall-site:
ifneq ($(Arch),arm)
	$(RM) $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/$(Namespace)/$(ShortPackage)
endif
