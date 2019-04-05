%define _package __package__
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
#%define _includedirs __includedirs__

%define _unpackaged_files_terminate_build 0

%define _is_arm __is_arm__

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
%if %{_is_arm}
AutoReqProv: no
%endif

%description
__description__

%package -n %{_packagename}-devel
Summary: Development package for %{_summary}
Requires: %{_packagename}

%description -n %{_packagename}-devel
__description__

# %package -n %{_packagename}-debuginfo
# Summary: Debuginfo for %{_summary}
# Requires: %{_packagename}

# %description -n %{_packagename}-debuginfo
# __description__

# %pre

# %prep

# %setup

# %build

#
# Prepare the list of files that are the input to the binary and devel RPMs
#
%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/{bin,lib,include,etc,share,scripts}
mkdir -p $RPM_BUILD_ROOT/usr/lib/debug%{_prefix}/{bin,lib}
mkdir -p $RPM_BUILD_ROOT/usr/src/debug/%{_project}/%{_packagename}-%{_version}

if [ -d %{_packagedir}/bin ]; then
  cd %{_packagedir}/bin; \
  find . -name "*"  -exec install -D -m 755 {} $RPM_BUILD_ROOT/%{_prefix}/bin/{} \;
fi

if [ -d %{_packagedir}/src ]; then
  cd %{_packagedir}/src; \
  find . \( -name "*.cpp" -o -name "*.cxx" -o -name "*.c" -o -name "*.C" -o -name "*.cc" \) \
       -exec install -D -m 644 {} $RPM_BUILD_ROOT/%{_prefix}/src/{} \;
  # find src -name '*.cc' -fprintf rpm/debug.source "%p\0";
fi

if [ -d %{_packagedir}/include ]; then
  cd %{_packagedir}/include; \
  find . \( -name "*.hpp" -o -name "*.hxx" -o -name "*.h" -o -name "*.hh" \) \
       -exec install -D -m 644 {} $RPM_BUILD_ROOT/%{_prefix}/include/{} \;
  # find include -name '*.h' -fprintf rpm/debug.include "%p\0";
fi

if [ -d %{_packagedir}/lib ]; then
  cd %{_packagedir}/lib; \
  find . -name "*.so" -exec install -D -m 755 {} $RPM_BUILD_ROOT/%{_prefix}/lib/{} \;
fi

if [ -d %{_packagedir}/etc ]; then
  cd %{_packagedir}/etc; \
  find ./ \( -name ".svn" -name ".git" \) -prune -o -name "*" -type f \
       -exec install -D -m 644 {} $RPM_BUILD_ROOT/%{_prefix}/etc/{} \;
fi

if [ -d %{_packagedir}/scripts ]; then
  cd %{_packagedir}/scripts; \
  find ./ -name ".svn" -prune -o -name "*" -type f \
       -exec install -D -m 655 {} $RPM_BUILD_ROOT/%{_prefix}/scripts/{} \;
fi

# #create debug.source - SLC6 beardy wierdo "feature"
# cd %{_packagedir}
# touch rpm/debug.include
# touch rpm/debug.source
# #find src include -name '*.h' -print > rpm/debug.source -o -name '*.cc' -print > rpm/debug.source

# # Copy all sources and include files for debug RPMs
# cat %{_packagedir}/rpm/debug.source | sort -z -u | egrep -v -z '(<internal>|<built-in>)$' | ( cpio -pd0mL --quiet "$RPM_BUILD_ROOT/usr/src/debug/%{_project}/%{_packagename}-%{_version}" )
# cat %{_packagedir}/rpm/debug.include | sort -z -u | egrep -v -z '(<internal>|<built-in>)$' | ( cpio -pd0mL --quiet "$RPM_BUILD_ROOT/usr/src/debug/%{_project}/%{_packagename}-%{_version}" )
# # correct permissions on the created directories
# cd "$RPM_BUILD_ROOT/usr/src/debug/"
# find ./ -type d -exec chmod 755 {} \;

%clean
rm -rf $RPM_BUILD_ROOT

#
# Files that go in the binary RPM
#
%files
%defattr(-,root,root,0755)
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

# %define add_arm_libs %( if [[ '__buildarch__' =~ "arm" ]] || [ -d 'lib/arm' ]; then echo "0" ; else echo "1"; fi )
%define add_arm_libs %( if [ -d 'lib/arm' ]; then echo "1" ; else echo "0"; fi )
%define is_arm  %( if [[ '__buildarch__' =~ "arm" ]]; then echo "1" ; else echo "0"; fi )

%files -n %{_packagename}-devel
%defattr(-,root,root,0755)
%if %add_arm_libs
%attr(0755,root,root) %{_prefix}/lib/arm/*.so
%endif

%dir
%{_prefix}/include

# #
# # Files that go in the debuginfo RPM
# #
# %files -n %{_packagename}-debuginfo
# %defattr(-,root,root,0755)

# %dir
# /usr/lib/debug
# /usr/src/debug

%post

%preun

%postun

%changelog

#%doc MAINTAINER ChangeLog README
