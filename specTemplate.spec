%define _package __package__
%define _longpackage __longpackage__
%define _packagename __packagename__
%define _version __version__
%define _release __release__
%define _prefix  __prefix__
%define _sources_dir __sources_dir__
%define _tmppath /tmp
%define _packagedir __packagedir__
%define _os __os__
%define _platform __platform__
%define _project __project__
%define _author __author__
%define _summary __summary__
%define _url __url__
%define _buildarch __buildarch__
#%%define _includedirs __includedirs__

%define _unpackaged_files_terminate_build 0

%define add_arm_libs %( if [ -d 'lib/arm' ]; then echo "1" ; else echo "0"; fi )
%define is_arm  %( if [[ '__buildarch__' =~ "arm" ]]; then echo "1" ; else echo "0"; fi )

%global _find_debuginfo_opts -g

#
# Binary RPM specified attributed (lib and bin)
#
Name: %{_packagename}
Summary: %{_summary}
Version: %{_version}
Release: %{_release}
Packager: %{_author}
#BuildArch: %{_buildarch}
License: __license_
# Group: Applications/extern
URL: %{_url}
BuildRoot: %{_tmppath}/%{_packagename}-%{_version}-%{_release}-buildroot
Prefix: %{_prefix}
Requires: __requires_list__
BuildRequires: __build_requires_list__
%if %{is_arm}
AutoReq: no
%endif

%description
__description__

%package -n %{_packagename}-devel
Summary: Development package for %{_summary}
Requires: %{_packagename}

%description -n %{_packagename}-devel
__description__

%package -n %{_packagename}-debuginfo
Summary: Debuginfo for %{_summary}
Requires: %{_packagename}

%description -n %{_packagename}-debuginfo
__description__

# %pre

%prep
## if there is a Source tag that points to the tarball
#%%setup -q
cp %{_sourcedir}/%{_project}-%{_longpackage}-%{_version}.tbz2 ./
tar xjf %{_project}-%{_longpackage}-%{_version}.tbz2

%build
cd %{_project}/%{_packagename}
make -j4

#
# Prepare the list of files that are the input to the binary and devel RPMs
#
%install
rm -rf %{buildroot}
pushd %{_project}/%{_packagename}
INSTALL_PREFIX=%{buildroot} make install
touch ChangeLog README LICENSE MAINTAINER
popd

## Manually run find-debuginfo because...?
## maybe only on x86_64
/usr/lib/rpm/find-debuginfo.sh -g -m -r --strict-build-id

%clean
rm -rf %{buildroot}

#
# Files that go in the binary RPM
#
%files
%defattr(-,root,root,0755)
%doc %{_project}/%{_packagename}/MAINTAINER.md %{_project}/%{_packagename}/CHANGELOG.md %{_project}/%{_packagename}/README.md %{_project}/%{_packagename}/LICENSE
%attr(0755,root,root) %{_prefix}/lib/*.so

%dir
%{_prefix}/bin
%{_prefix}/scripts

#
# Files that go in the devel RPM
#

## Want to exclude all files in lib/arm from being scanned for dependencies, but need to make sure this doesn't break other packages
# Do not check any files in lib/arm for requires
%global __requires_exclude_from ^%{_prefix}/lib/arm/.*$

# Do not check .so files in an arm-specific library directory for provides
%global __provides_exclude_from ^%{_prefix}/lib/arm/*\\.so$

%files -n %{_packagename}-devel
%defattr(-,root,root,0755)
%doc %{_project}/%{_packagename}/MAINTAINER.md %{_project}/%{_packagename}/CHANGELOG.md %{_project}/%{_packagename}/README.md %{_project}/%{_packagename}/LICENSE
%if %add_arm_libs
%attr(0755,root,root) %{_prefix}/lib/arm/*.so
%endif

%dir
%{_prefix}/include

#
# Files that go in the debuginfo RPM
#
%files -n %{_packagename}-debuginfo
%defattr(-,root,root,0755)
%doc %{_project}/%{_packagename}/MAINTAINER.md %{_project}/%{_packagename}/CHANGELOG.md %{_project}/%{_packagename}/README.md %{_project}/%{_packagename}/LICENSE

%dir
/usr/lib/debug
/usr/src/debug

%post

%preun

%postun

%changelog

