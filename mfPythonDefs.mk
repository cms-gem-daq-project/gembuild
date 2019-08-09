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
# reg_interface_gem-3.2.2-final.dev106.zip
	pip install $(RPM_DIR)/$(PackageName)-$(PACKAGE_FULL_VERSION)$(PREREL_VERSION).zip

install-site:
ifneq ($(Arch),arm)
	$(MakeDir) $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/$(Namespace)/$(ShortPackage)
	@if [ -d pkg ]; then \
	   cd pkg; \
	   find $(Namespace) -type f -exec install -D -m 755 {} $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/$(Namespace)/$(ShortPackage)/{} \; ; \
	fi
endif

uninstall-pip:
	pip uninstall $(PackageName)

uninstall-site:
ifneq ($(Arch),arm)
	$(RM) $(INSTALL_PREFIX)$(PYTHON_SITE_PREFIX)/$(Namespace)/$(ShortPackage)
endif
