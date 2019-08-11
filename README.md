# gembuild
This package provides a set of generic scripts to standardize building of GEM DAQ software.

## Usage
This repository should be checked out during a build, or added to the repository as a submodule at `REPO_BASE/config`
Then, in the calling `Makefile`, the appropriate `include` should be made.

## Contents
This repository contains various common definitions and templates for driving the build process, as well as some scripts.

### `tag2rel.sh`
This script will extract automatically the version, build, and release information based on the `git` tag.
For more information, execute `tag2rel.sh -h`

### `make` helpers
Targets that are defined within with a leading `_` are not intended to be used outside of the config package.a
They should be neither overridden nor used as depndencies

#### `mfCommonDefs.mk`
Most common definitions needed, and basic targets.
* Provides several common dependent directories with `?=` assignments, so they are easy to override elsewhere.
* Sets several variables for metadata:
  * `GEM_PLATFORM`: the development platform
  * `GEM_OS`: the development operating system
  * `GIT_VERSION`: the `git` version
  * `GEMDEVELOPER`: the developer's name
  * `GITREV`: the `git` short hash
  * `BUILD_DATE`: the date
  * `BUILD_VERSION`: will be used as the `Release`, and is extracted using `tag2rel.sh`
  * `PREREL_VERSION`: will be used as part of the `pip` package name, and is extracted using `tag2rel.sh`
* Package structure variables:
  * `INSTALL_PATH` is the base directory of the installed project, defaults to `/opt/$(Project)`
  * `ProjectPath` is the base directory of the project, defaults to `$(BUILD_HOME)/$(Project)`
  * `PackagePath` is the base directory of the package, defaults to `$(ProjectPath)`
  * `PackageIncludeDir`: location of the headers, defaults to `$(PackagePath)/include`
  * `PackageSourceDir`: location of the source files, defaults to `$(PackagePath)/src`
  * `PackageTestSourceDir`: location of source files to build into executables, defaults to `$(PackagePath)/test`
  * `PackageLibraryDir`: location of library files, defaults to `$(PackagePath)/lib`
  * `PackageExecDir`: location of executables, defaults to `$(PackagePath)/bin`
  * `PackageObjectDir`: location of object files, defaults to `$(PackageSourceDir)/linux/$(Arch)`
* Defines `default`, `clean`, `build`, `doc`, `all`, `install` and `uninstall` `make` targets
  * `all` has a dependency on `build`
* Provides `install` and `uninstall` `make` targets
  * `install` depends on `all` and will copy all generated files to the expected installed package structure
  * `uninstall` removes any files created during `install`

#### `mfPythonDefs.mk`
Additional definitions for `python` packages, and `python` package specific targets.

* Provides `install-site` and `uninstall-site` `make` targets
  * `install-site` depends on `rpmprep` and will copy all generated files to the expected installed package structure
  * `uninstall-site` removes any files created during `install-site`

#### `mfRPMRules.mk`
Definitions needed to package into RPMs.
Allows setting of required packages, as well as build required packages from a `packageinfo.h` file, located in `$(PackagePath)/include`
* variables
  * `RPM_DIR` directory where package RPM will be built, defaults to `$(PackagePath)/rpm`
  * `RPMBUILD_DIR` the actual rpmbuild directory, defaults to `$(RPM_DIR)/RPMBUILD`
* targets
  * `rpmprep` should be defined to do any setup necessary between compiling and making the RPM, `rpm` depends on it
  * `cleanrpm` removes `$(RPMBUILD_DIR)`, note that it does *not* remove the RPMs

Defines `rpm` target, dependent on a `spec_update` target which fills the template spec file

#### `mfPythonRPM.mk`
Sets up environment and rules for packaging `python` packages.
* variables
  * `RPM_DIR` directory where package RPM will be built, defaults to `$(PackagePath)/rpm`
  * `RPMBUILD_DIR` the actual rpmbuild directory, defaults to `$(RPM_DIR)/build`
* targets
  * `pip` creates a zip file, installable with `pip`
  * `rpmprep` should be defined to do any setup necessary between compiling and making the RPM, `rpm` depends on it
  * `cleanrpm` removes `$(RPMBUILD_DIR)`, note that it does *not* remove the RPMs
  * `cleanallrpm` removes `$(RPM_DIR)`

#### `mfSphinx.mk`
Sets up the environment for building `sphinx` documentation and provides the necessary targets.

#### `mfZynq.mk`
Extra definitions for building on a Xilinx `Zynq` SoC

* `CFLAGS`
* `LDLIBS` set to include locations provided in the `PETA_STAGE`
* `LDFLAGS` turns on `-g` by default, adds library locations from `LDLIBS`
* `INSTALL_PATH` is changed to `/mnt/persistent/$(Project)`
* Compiler toolchain is set to the `arm-linux-gnueabihf` toolchain, provided by the `Xilinx` SDK, with `:=` operator

### Packaging templates
#### `setupTemplate.cfg`
A generic `setup.cfg` file for `python` packages.
The values will be populated based on variables at the time the rule is executed.
This file will be ignored if a package specific template already exists.

#### `setupTemplate.py`
A generic `setup.py` file for `python` packages.
The values will be populated based on variables at the time the rule is executed.
This file will be ignored if a package specific template already exists.

#### `specTemplate.spec`
A generic `spec` file for building RPM packages.
The values will be populated based on variables at the time the rule is executed.
This file will be ignored if a package specific template already exists.
