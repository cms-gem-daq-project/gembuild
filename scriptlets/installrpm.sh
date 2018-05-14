#!/bin/sh

# default action
python setup.py install --single-version-externally-managed -O1 --root=$RPM_BUILD_ROOT --record=INSTALLED_FILES

# install 'scripts' to /opt/cmsgemos/bin
mkdir -p %{buildroot}/opt/cmsgemos/bin
cp -rfp gempython/scripts/*.py %{buildroot}/opt/cmsgemos/bin/

# remove the namespace gempython __init__.pyc[o] files from the RPM
find %{buildroot} -wholename "*gempython/__init__.py" -delete
find %{buildroot} -wholename "*gempython/__init__.pyo" -delete
find %{buildroot} -wholename "*gempython/__init__.pyc" -delete
find %{buildroot} -wholename '*site-packages/gempython/__init__.py' -delete
find %{buildroot} -wholename '*site-packages/gempython/__init__.pyc' -delete
find %{buildroot} -wholename '*site-packages/gempython/__init__.pyo' -delete
find %{buildroot} -type f -exec chmod a+r {} \;
find %{buildroot} -type f -iname '*.cfg' -exec chmod a-x {} \;

cp INSTALLED_FILES INSTALLED_FILES.backup
cat INSTALLED_FILES.backup|egrep -v 'gempython/__init__.py*' > INSTALLED_FILES
# set permissions
cat <<EOF >>INSTALLED_FILES
%attr(0755,root,root) /opt/cmsgemos/bin/*.py
%attr(0644,root,root) /usr/lib/python*/site-packages/gempython/**/*.py
%attr(0644,root,root) /usr/lib/python*/site-packages/gempython/**/*.pyo
%attr(0644,root,root) /usr/lib/python*/site-packages/gempython/**/*.pyc
%attr(0755,root,root) /usr/lib/python*/site-packages/gempython/scripts/*.py
%exclude /usr/lib/python*/site-packages/gempython/__init__.py
%exclude /usr/lib/python*/site-packages/gempython/__init__.pyc
%exclude /usr/lib/python*/site-packages/gempython/__init__.pyo
EOF
echo "Modified INSTALLED_FILES"
cat INSTALLED_FILES
