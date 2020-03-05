# gembuild
This package provides a set of generic scripts to standardize building of GEM DAQ software.

## Usage
This repository should be checked out during a build, or (preferably) added to the repository as a submodule at `REPO_BASE/config`
Then, in the package `Makefile`, the appropriate `include` statement(s) should be made.

## Contents
This repository contains various common definitions and templates for driving the build process, as well as some additional helper scripts.

### Helper scripts
#### `tag2rel.sh`
This script will extract automatically the version, build, and release information based on the `git` tag information (if present).
It has been tested to work fully with `git` version `2.18`, but should also work with earlier versions.

#### CI
##### `gitlab-ci-template.yml`
A starter template that may be copied into the project root to set up CI with CERN GitLab

##### `utils.sh`
Provides several functions that are used by other CI scripts

##### `generate_repo.sh`
Populates a repository tree structure for easy deployment.
Also creates the `yum` `.repo` file.

##### `publish_eos.sh`
Perform the actual publication of artifacts (`rpm`s, docs, source tarballs) to the cmsgemdaq EOS hosted web area

##### `parse_api_changes.sh`
Designed to be able to run a check of the API/ABI compatibility between versions of the code.
Not fully validated

### `make` helpers
Targets that are defined within with a leading `_` are not intended to be used outside of the `config` package.
They should be neither overridden nor used as dependencies

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
* Sets variables for standard lookup paths, these may be overridden as needed:
  * `CMSGEMOS_ROOT` : location of the installed `cmsgemos` package, defaults to `/opt/cmsgemos`
  * `CACTUS_ROOT` : location of the installed `cactus` (`uhal` and `amc13`) packages, defaults to `/opt/cactus`
  * `XDAQ_ROOT` : location of the installed `xdaq` package, defaults to `/opt/xdaq`
  * `XHAL_ROOT` : location of the installed `xhal` package, defaults to `/opt/xhal`
  * `REEDMULLER_ROOT` : location of the installed `reedmuller-c` package, defaults to `/opt/reedmuller`
  * `WISCRPC_ROOT` : location of the installed `wiscrpcsvc` package, defaults to `/opt/wiscrpcsvc`

##### Compilation
Sets up common compiler and compiler flags
* `CFLAGS` flags to pass to the `C` compiler
* `CXXFLAGS` flags to pass to the `C++` compiler, will usually append `CFLAGS` before any `C` specific flags are added to `CFLAGS`
* `LDFLAGS` set to `-g`, and may be appended to in the package `Makefile` to add any additional desired flags to be passed to the linker
* `LDLIBS` empty by default, and should be appended to in the package `Makefile` to add any additional libraries to link against
* `OPTFLAGS` set (if not already set) to `-g -O2`, this is overridden during special builds, e.g., `make checkabi`, where a specific optimization is desired
* `SOFLAGS` set to `-shared `and may be appended to in the package `Makefile` to add any additional flags to be passed to the linker for creating shared objects

##### `UseSONAMEs`
This variable is be used to determine whether or not the libraries will be compiled with the `soname` option, default is yes, and in that case, the following variables will be set:
* `LibrarySONAME` will be set to `$(@F).$(PACKAGE_ABI_VERSION)`
* `LibraryFull` will be set to `$(@F).$(PACKAGE_FULL_VERSION)`
* `LibraryLink` will be set to `$(@F)`
* `SOFLAGS` will have `-Wl,-soname,$(LibrarySONAME)` appended
* The function `link-sonames` will create the appropriate symlinks to the compiled library
* If `UseSONAMEs` is overridden to any other value
  * `LibrarySONAME` and `LibraryFull` will both be set to `$(@F)`, and no symlinks will be generated

##### Package structure variables
* `INSTALL_PREFIX` : where to install the project, defaults to `/`, may be overridden for non-system installation
* `INSTALL_PATH` : base directory of the installed project, defaults to `/opt/$(Project)`, **should not be overridden**
* `PETA_PATH` : base directory where cross-compilation libraries will be installed on the host, defaults to `/opt/gem-peta-stage`, **should not be overridden**
* `ProjectPath` : base directory of the project, defaults to `$(BUILD_HOME)/$(Project)`
* `PackagePath` : base directory of the package, defaults to `$(ProjectPath)`
* `PackageIncludeDir`: location of the headers, defaults to `$(PackagePath)/include`
* `PackageSourceDir`: location of the source files, defaults to `$(PackagePath)/src`
* `PackageTestSourceDir`: location of source files to build into executables, defaults to `$(PackagePath)/test`
* `PackageLibraryDir`: location of library files, defaults to `$(PackagePath)/lib`
* `PackageExecDir`: location of executables, defaults to `$(PackagePath)/bin`
* `PackageObjectDir`: location of object files, defaults to `$(PackageSourceDir)/linux/$(Arch)`

##### Common targets (implicit and explicit)
* All targets can be printed with `make help` to get common information
* Defines `all`, `build`, `clean`, `cleandoc`, `cleanrpm`, `cleanallrpm`, `cleanall`, `default`, `doc` `make` `.PHONY` targets, which should be implemented in the package `Makefile`
  * `all` has a dependency on `build`
  * `cleanall` has a dependency on `clean`, `cleandoc`, `cleanallrpm`, `cleanrelease`
* Provides implementation of `cleanrelease`, `release`, `install` and `uninstall` `.PHONY` `make` targets
  * `cleanrelease`  will remove all packaged files from the publishing prep location
  * `release` depends on `doc` and `rpm`, and will copy all packaged files to the structure expected by the CI for publishing
  * `install` depends on `all` and will copy all generated files to the expected installed package structure
  * `uninstall` removes any files created during `install`
* Provides implementation of `crosslibinstall` and `crosslibuninstall` `.PHONY` `make` targets for non-`x86_64` architectures
  * `crosslibinstall` will place the cross-compiled libraries into the `INSTALL_PATH` tree where they would appear in the `gem-peta-stage` area
  * `crosslibuninstall` removes any files created during `crosslibinstall`
* Provides `checkabi` and several dependent targets
  * Performs an ABI check on two versions of a library

#### `mfPythonDefs.mk`
Additional definitions for `python` packages, and `python` package specific targets.
* `PYVER` is the version of the `python` interpreter to use, e.g., `pypy`, `python`, `python2`, `python3.6`, etc.,
* Provides `install-site` and `uninstall-site` `make` targets (which are also added as dependencies of the generic `(un)install` targets)
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
    * e.g., in the package `Makefile` set `$(PackageSpecFile): path/to/overide/template`
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
    * e.g., in the package `Makefile` set `$(PackageSetupFile): path/to/overide/setup.py` (this file *must* be in one of the locations that the rule looks, see [here](#setuptemplatepy))
  * `cleanrpm` removes `$(RPMBUILD_DIR)`, note that it does *not* remove the RPMs
  * `cleanallrpm` removes `$(RPM_DIR)`

#### `mfSphinx.mk`
Sets up the environment for building `sphinx` documentation and provides the necessary targets.

#### `mfZynq.mk`
Extra definitions for building on a Xilinx `Zynq` SoC (currently specific to the UW CTP7)

* `PETA_STAGE` is the location where the compiler will look for headers and libraries when cross-compiling, defaults to `$(PETA_PATH)`, may be overridden if developing features in multiple projects simultaneously.
* `LDFLAGS` adds library locations from `PETA_STAGE`
* `INSTALL_PATH` is changed to `/mnt/persistent/$(Project)`
* Compiler toolchain is set to the `arm-linux-gnueabihf` toolchain, provided by the `Linaro`, with `:=` operator

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

#### `setupTemplate.(cfg|py)`
Generic `setup.cfg` and `setup.py` files for `python` packages.
The values will be populated based on variables at the time the rule is executed.
This file will be ignored if a package specific template already exists, searching in order:
```
$(PackagePath)/setup.(cfg|py)
$(PackagePath)/pkg/setup.(cfg|py)
$(ProjectPath)/config/setupTemplate.(cfg|py)
```

#### `specTemplate.spec`
A generic `spec` file for building RPM packages.
The values will be populated based on variables at the time the rule is executed.
This file will be ignored if a package specific template already exists, searching in order:
```
$(PackagePath)/spec.template
$(ProjectPath)/config/specTemplate.spec
```

## Examples
### Multiple simultaneous developments
If developing, e.g,. both `xhal` and `ctp7_modules` simultaneously:

#### Create a local `xhal` installation
```sh
cd /path/to/xhal
INSTALL_PREFIX=/path/to/local/installation make install
```

#### Use local `xhal` installation when compiling `ctp7_modules`
##### Set up the local `PETA_STAGE` area
If working with multiple target boards, repeat for each
```sh
ln -ns /opt/gem-peta-stage/ctp7/usr /path/to/local/installation/opt/gem-peta-stage/ctp7/
ln -ns /opt/gem-peta-stage/ctp7/lib /path/to/local/installation/opt/gem-peta-stage/ctp7/
## link in any system installed packages you're not modifying
ln -ns /opt/gem-peta-stage/ctp7/mnt/persistent/reedmuller /path/to/local/installation/opt/gem-peta-stage/ctp7/mnt/persistent/
```
##### Move to `ctp7_modules` work area
```sh
cd /path/to/ctp7_modules
export PETA_STAGE=/path/to/local/installation/opt/gem-peta-stage
## if making a local installation of this
INSTALL_PREFIX=/path/to/local/installation make install
## if just compiling against the local changes in `xhal`
make
```
