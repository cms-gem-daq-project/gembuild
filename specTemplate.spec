%define _package __package__
%define _longpackage __longpackage__
%define _packagename __packagename__
%define _version __version__
%define _short_release __short_release__
%define _prefix  __prefix__
#%%define _sources_dir __sources_dir__
%define _tmppath /tmp
#%%define _packagedir __packagedir__
%define _os __os__
%define _platform __platform__
%define _project __project__
%define _author __author__
%define _summary __summary__
%define _url __url__
%define _buildarch __buildarch__
#%%define _includedirs __includedirs__

%global _binaries_in_noarch_packages_terminate_build 0
%global _unpackaged_files_terminate_build 0

### find . -type d -wholename '*/lib/arm'
#%%global add_arm_libs %( if [ -d '%{_packagedir}/lib/arm' ]; then echo "1" ; else echo "0"; fi )
%global is_arm  %( if [[ '__buildarch__' =~ "arm" ]]; then echo "1" ; else echo "0"; fi )
%global not_arm  %( if [[ ! '__buildarch__' =~ "arm" ]]; then echo "1" ; else echo "0"; fi )

%global _find_debuginfo_opts -g

#
# Binary RPM specified attributed (lib and bin)
#
Name: %{_packagename}
Summary: %{_summary}
Version: %{_version}
Release: %{_release}
Packager: %{_author}
# BuildArch: %{_buildarch}
License: __license__
URL: %{_url}
# Source: %{_source_url}/%{_project}-%{_longpackage}-%{_version}-%{_short_release}.tbz2
BuildRoot: %{_tmppath}/%{_packagename}-%{_version}-%{_release}-buildroot
Prefix: %{_prefix}
%if 0%{?_requires}
Requires: __requires_list__
%endif

%if 0%{?_build_requires}
BuildRequires: __build_requires_list__
%endif

%if %{is_arm}
AutoReq: no
%endif

%description
__description__

## Only build devel RPMs for non-ARM
%if %not_arm
%package -n %{_packagename}-devel
Summary: Development files for %{_packagename}
Requires: %{_packagename}

%description -n %{_packagename}-devel
Development headers for the %{_packagename} package

%endif

## Only build debuginfo RPMs for non-ARM?
#%%%if %not_arm
%package -n %{_packagename}-debuginfo
Summary: Debuginfos for %{_packagename}
Requires: %{_packagename}, %{_packagename}-devel

%description -n %{_packagename}-debuginfo
Debuginfos for the %{_packagename} package

#%%%endif

# %pre

%prep
## if there is a Source tag that points to the tarball
#%%setup -q
mv %{_sourcedir}/%{_project}-%{_longpackage}-%{_version}-%{_short_release}.tbz2 ./
tar xjf %{_project}-%{_longpackage}-%{_version}-%{_short_release}.tbz2

## update extracted timestamps if doing a git build
find %{_project}/%{_packagename} -type f -iname '*.h' -print0 -exec touch {} \+
find %{_project}/%{_packagename} -type f -iname '*.cpp' -print0 -exec touch {} \+
find %{_project}/%{_packagename} -type f -iname '*.d' -print0 -exec touch {} \+
find %{_project}/%{_packagename} -type f -iname '*.o' -print0 -exec touch {} \+
find %{_project}/%{_packagename} -type f -iname '*.so*' -print0 -exec touch {} \+
find %{_project}/%{_packagename} -type l -iname '*.so*' -print0 -exec touch -h {} \+

%build
# pushd %{_project}/%{_packagename}
# make build -j4
# popd

#
# Prepare the list of files that are the input to the binary and devel RPMs
#
%install
rm -rf %{buildroot}
pushd %{_project}/%{_packagename}
INSTALL_PREFIX=%{buildroot} make install
touch ChangeLog README LICENSE MAINTAINER CHANGELOG.md
popd

## Manually run find-debuginfo because...?
## maybe only on x86_64?
/usr/lib/rpm/find-debuginfo.sh -g -m -r --strict-build-id

%clean
rm -rf %{buildroot}

#
# Files that go in the binary RPM
#
%files
%defattr(-,root,root,0755)
%attr(0755,root,root) %{_prefix}/lib/*.so*

%dir

%doc %{_project}/%{_packagename}/MAINTAINER.md
%doc %{_project}/%{_packagename}/README.md
%doc %{_project}/%{_packagename}/CHANGELOG.md
%license %{_project}/%{_packagename}/LICENSE

#### Only build devel RPMs for non-ARM ####
%if %not_arm

#
# Files that go in the devel RPM
#

# Do not check any files in lib/arm for requires
# Do not check .so files in an arm-specific library directory for provides
%define __requires_exclude_from ^%{_prefix}/lib/arm/.*$
%define __provides_exclude_from ^%{_prefix}/lib/arm/.*$
%define __requires_exclude ^%{_prefix}/lib/arm/.*\\.so.*$
%define __provides_exclude ^%{_prefix}/lib/arm/.*\\.so.*$

%files -n %{_packagename}-devel
%defattr(-,root,root,0755)

#%%if %add_arm_libs
#%%attr(0755,root,root) %{_prefix}/lib/arm/*.so
#%%endif

%dir
%{_prefix}/lib/arm
%{_prefix}/include

%doc %{_project}/%{_packagename}/MAINTAINER.md
%doc %{_project}/%{_packagename}/README.md
%doc %{_project}/%{_packagename}/CHANGELOG.md
%license %{_project}/%{_packagename}/LICENSE

%endif

#### Only build debuginfo RPMs for non-ARM? ####
#%%%if %not_arm
#
# Files that go in the debuginfo RPM
#
%files -n %{_packagename}-debuginfo
%defattr(-,root,root,0755)

%dir
/usr/lib/debug/%{_prefix}
/usr/src/debug/%{_packagename}-%{_version}

%doc %{_project}/%{_packagename}/MAINTAINER.md
%doc %{_project}/%{_packagename}/README.md
%doc %{_project}/%{_packagename}/CHANGELOG.md
%license %{_project}/%{_packagename}/LICENSE

#%%##%%%endif

%post

%preun

%postun

%changelog
