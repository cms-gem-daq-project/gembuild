#!/bin/sh

# default action
python setup.py install --single-version-externally-managed -O1 --root=$RPM_BUILD_ROOT --record=INSTALLED_FILES

# install 'scripts' to __PYTHON_SCRIPT_PATH__
mkdir -p %{buildroot}/__PYTHON_SCRIPT_PATH__
cp -rfp __PYTHON_NAMESPACE__/scripts/*.py %{buildroot}/__PYTHON_SCRIPT_PATH__/

# remove the namespace __PYTHON_NAMESPACE__ __init__.pyc[o] files from the RPM
find %{buildroot} -wholename "*__PYTHON_NAMESPACE__/__init__.py" -delete
find %{buildroot} -wholename "*__PYTHON_NAMESPACE__/__init__.pyo" -delete
find %{buildroot} -wholename "*__PYTHON_NAMESPACE__/__init__.pyc" -delete
find %{buildroot} -wholename '*site-packages/__PYTHON_NAMESPACE__/__init__.py' -delete
find %{buildroot} -wholename '*site-packages/__PYTHON_NAMESPACE__/__init__.pyc' -delete
find %{buildroot} -wholename '*site-packages/__PYTHON_NAMESPACE__/__init__.pyo' -delete
find %{buildroot} -wholename '*site-packages/__PYTHON_NAMESPACE__/*/macros/*.py' -print0 -exec chmod a+x {} \;
find %{buildroot} -type f -exec chmod a+r {} \;
find %{buildroot} -type f -iname '*.cfg' -exec chmod a-x {} \;

cp INSTALLED_FILES INSTALLED_FILES.backup
cat INSTALLED_FILES.backup|egrep -v '__PYTHON_NAMESPACE__/__init__.py*' > INSTALLED_FILES
# set permissions
cat <<EOF >>INSTALLED_FILES
%attr(0755,root,root) __PYTHON_SCRIPT_PATH__/*.py
%attr(0755,root,root) %{python2_sitelib}/__PYTHON_NAMESPACE__/scripts/*.py

%dir __PYTHON_SCRIPT_PATH__
EOF
echo "Modified INSTALLED_FILES"
cat INSTALLED_FILES
