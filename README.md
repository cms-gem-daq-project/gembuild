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

##### `UseSONAMEs`
This variable is be used to determine whether or not the libraries will be compiled with the `soname` option, default is yes, and in that case, the following variables will be set:
* `LibrarySONAME` will be set to `$(@F).$(PACKAGE_ABI_VERSION)`
* `LibraryFull` will be set to `$(@F).$(PACKAGE_FULL_VERSION)`
* `LibraryLink` will be set to `$(@F)`
* `LDFLAGS_SONAME` will then be set to `-Wl,-soname,$(LibrarySONAME)`
* The function `link-sonames` will create the appropriate symlinks to the compiled library
* If `UseSONAMEs` is overridden to any other value
  * `LibrarySONAME` and `LibraryFull` will both be set to `$(@F)`, and no symlinks will be generated

##### Package structure variables
* `INSTALL_PATH` is the base directory of the installed project, defaults to `/opt/$(Project)`
* `ProjectPath` is the base directory of the project, defaults to `$(BUILD_HOME)/$(Project)`
* `PackagePath` is the base directory of the package, defaults to `$(ProjectPath)`
* `PackageIncludeDir`: location of the headers, defaults to `$(PackagePath)/include`
* `PackageSourceDir`: location of the source files, defaults to `$(PackagePath)/src`
* `PackageTestSourceDir`: location of source files to build into executables, defaults to `$(PackagePath)/test`
* `PackageLibraryDir`: location of library files, defaults to `$(PackagePath)/lib`
* `PackageExecDir`: location of executables, defaults to `$(PackagePath)/bin`
* `PackageObjectDir`: location of object files, defaults to `$(PackageSourceDir)/linux/$(Arch)`

##### Common targets (implicit and explicit)
* Defines `default`, `clean`, `build`, `doc`, `all`, `release`, `install` and `uninstall` `make` targets
  * `all` has a dependency on `build`
* Provides `release`, `install` and `uninstall` `make` targets
  * `release` depends on `rpm` and will copy all packaged files to the structure expected by the CI for publishing
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
  * `TargetSRPMName` is used to only rebuild the SRPM when necessary, is set to `$(RPM_DIR)/$(PackageName).src.rpm`
  * `TargetRPMName` is used to only rebuild the RPM when necessary, is set to `$(RPM_DIR)/$(PackageName).$(GEM_ARCH).rpm`
  * `PackageSpecFile` is used to only update the spec file when necessary and is set to `$(RPM_DIR)/$(PackageName).spec`
* targets
  * `$(PackageSpecFile)` depends on `$(ProjectPath)/config/specTemplate.spec`, and should be overridden if a more specific template is defined in the package, in order to ensure the RPMs are rebuilt when the spec file changes
    * e.g., in your package `Makefile` set `$(PackageSpecFile): path/to/overide/template`
  * `$(TargetSRPMName)` depends on `$(PackageSpecFile)` and has an order-only dependency on `rpmprep`
  * `$(TargetRPMName)` depends on `$(PackageSpecFile)` and has an order-only dependency on `rpmprep`
  * `rpmprep` should be defined to do any setup necessary between compiling and making the RPM, `rpm` depends on it
    * The best practice would be to define another target which is a file dependency
  * `cleanrpm` removes `$(RPMBUILD_DIR)` and `$(PackageSpecfile)`, note that it does *not* remove the RPMs
  * `cleanallrpm` removes `$(RPM_DIR)`
  * `rpm`, dependent on `$(TargetSRPMName)` and `$(TargetRPMName)`, generates the RPMs and moves them to `$(RPM_DIR)/repos`

#### `mfPythonRPM.mk`
Sets up environment and rules for packaging `python` packages.
* variables
  * `RPM_DIR` directory where package RPM will be built, defaults to `$(PackagePath)/rpm`
  * `RPMBUILD_DIR` the actual rpmbuild directory, defaults to `$(RPM_DIR)/build`
  * `TargetPIPName` is used to only rebuild the `pip` package when necessary, is set to `$(RPM_DIR)/$(PackageName).zip`
  * `TargetSRPMName` is used to only rebuild the SRPM when necessary, is set to `$(RPM_DIR)/$(PackageName).src.rpm`
  * `TargetRPMName` is used to only rebuild the RPM when necessary, is set to `$(RPM_DIR)/$(PackageName).$(GEM_ARCH).rpm`
  * `PackageSetupFile` is used to only update the `setup.py` file when necessary and is set to `$(RPMBUILD_DIR)/setup.py`
  * `PackagePrepFile` is used to only update the the RPM build directory when necessary and is set to `$(PackageDir)/$(PackageName).prep`
* targets
  * `pip` creates a zip file, installable with `pip`
  * `rpmprep` should be defined to do any setup necessary between compiling and making the RPM, `rpm` depends on it
  * `PackagePrepFile` should populate the `pkg` (or `$(PackageDir)`) directory with up-to-date files for packaging
  * `PackageSetupFile` will populate the `$(PackageSetupFile)` with values from the environment
    * e.g., in your package `Makefile` set `$(PackageSetupFile): path/to/overide/setup.py` (this file *must* be in one of the locations that the rule looks, see [here](#setuptemplatepy))
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
This file will be ignored if a package specific template already exists, searching in order:
```
$(PackagePath)/setup.cfg
$(PackagePath)/pkg/setup.cfg
$(ProjectPath)/config/setupTemplate.cfg
```

#### `setupTemplate.py`
A generic `setup.py` file for `python` packages.
The values will be populated based on variables at the time the rule is executed.
This file will be ignored if a package specific template already exists, searching in order:
```
$(PackagePath)/setup.py
$(PackagePath)/pkg/setup.py
$(ProjectPath)/config/setupTemplate.py
```

#### `specTemplate.spec`
A generic `spec` file for building RPM packages.
The values will be populated based on variables at the time the rule is executed.
This file will be ignored if a package specific template already exists, searching in order:
```
$(PackagePath)/spec.template
$(ProjectPath)/config/specTemplate.spec
```
