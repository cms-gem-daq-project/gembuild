#!/bin/sh -xeu

# generate_repo.sh <os> <arch> <repodir>
GEM_OS=${1}
GEM_ARCH=${2}
ARTIFACTS_DIR=${3}
SOURCERPM_DIR=${4}

## or variables should come from the parent shell
## will fail for unset or unbound variables

RELEASE_PLATFORM=${GEM_OS}_${GEM_ARCH}
#PYTHON_VERSION=${PYEXE}$(${PYEXE} -c "import sys; sys.stdout.write(sys.version[:3])")
#BUILD_COMPILER=${COMPILER}$(${COMPILER} -dumpfullversion -dumpversion | sed -e 's|\.|_|g')
#RELEASE_PLATFORM=${RELEASE_PLATFORM}_${BUILD_COMPILER}
BUILD_VER=$(${BUILD_HOME}/${CI_PROJECT_NAME}/config/tag2rel.sh | \
                   awk '{split($$0,a," "); print a[5];}' | \
                   awk '{split($$0,b,":"); print b[2];}')
REL_VERSION=${BUILD_VER%.*}

mkdir -p ${ARTIFACTS_DIR}/repos/{tarballs,SRPMS}
mkdir -p ${ARTIFACTS_DIR}/repos/${RELEASE_PLATFORM}/{RPMS,DEBUGRPMS}
# mkdir -p ${ARTIFACTS_DIR}/repos/${PACKAGE_TYPE}/{tarballs,SRPMS}
# mkdir -p ${ARTIFACTS_DIR}/repos/${PACKAGE_TYPE}/${RELEASE_PLATFORM}/{RPMS,DEBUGRPMS}

## only for debugging
#tree -df ${ARTIFACTS_DIR}/repos

find ${SOURCERPM_DIR} \( -type d -wholename ${ARTIFACTS_DIR}/repos \) -prune -o -iname '*.src.rpm' \
     -print0 -exec mv -t ${ARTIFACTS_DIR}/repos/SRPMS {} \+ 2>&1 > /dev/null

find ${SOURCERPM_DIR} \( -type d -wholename ${ARTIFACTS_DIR}/repos \) -prune -o -iname '*-debuginfo*.rpm' \
     -print0 -exec mv -t ${ARTIFACTS_DIR}/repos/${RELEASE_PLATFORM}/DEBUGRPMS {} \+ 2>&1 > /dev/null

find ${SOURCERPM_DIR} \( -type d -wholename ${ARTIFACTS_DIR}/repos \) -prune -o -iname '*.rpm' \
     -print0 -exec mv -t ${ARTIFACTS_DIR}/repos/${RELEASE_PLATFORM}/RPMS {} \+ 2>&1 > /dev/null

find ${SOURCERPM_DIR} \( -type d -wholename ${ARTIFACTS_DIR}/repos \) -prune -o \
     \( -iname '*.tar.gz' -o -iname '*.tar.bz' -o -iname '*.tbz2' -o -iname '*.tgz' -o -iname '*.zip' \) \
     -print0 -exec mv -t ${ARTIFACTS_DIR}/repos/tarballs {} \+ 2>&1 > /dev/null

rename tar. t ${ARTIFACTS_DIR}/repos/tarballs/*tar*

### dump the yum repo file
cat <<EOF > ${ARTIFACTS_DIR}/${CI_PROJECT_NAME}_${REL_VERSION/./_}_${RELEASE_PLATFORM}.repo
[${CI_PROJECT_NAME}-base]
name     = ${CI_PROJECT_NAME} -- ${REL_VERSION} RPMs
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/releases/repos/${REL_VERSION}/base/${RELEASE_PLATFORM}/RPMS
enabled  = 1
gpgcheck = 0

[${CI_PROJECT_NAME}-base-sources]
name     = ${CI_PROJECT_NAME} -- ${REL_VERSION} source RPMs
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/releases/repos/${REL_VERSION}/base/SRPMS
enabled  = 0
gpgcheck = 0

[${CI_PROJECT_NAME}-base-debug]
name     = ${CI_PROJECT_NAME} -- ${REL_VERSION} debuginfo RPMs
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/releases/repos/${REL_VERSION}/base/${RELEASE_PLATFORM}/DEBUGRPMS
enabled  = 0
gpgcheck = 0

[${CI_PROJECT_NAME}-testing]
name     = ${CI_PROJECT_NAME} -- ${REL_VERSION} testing RPMs
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/releases/repos/${REL_VERSION}/testing/${RELEASE_PLATFORM}/RPMS
enabled  = 0
gpgcheck = 0

[${CI_PROJECT_NAME}-testing-sources]
name     = ${CI_PROJECT_NAME} -- ${REL_VERSION} testing source RPMs
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/releases/repos/${REL_VERSION}/testing/${RELEASE_PLATFORM}/SRPMS
enabled  = 0
gpgcheck = 0

[${CI_PROJECT_NAME}-testing-debug]
name     = ${CI_PROJECT_NAME} -- ${REL_VERSION} testing debuginfo RPMs
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/releases/repos/${REL_VERSION}/testing/${RELEASE_PLATFORM}/DEBUGRPMS
enabled  = 0
gpgcheck = 0

[${CI_PROJECT_NAME}-unstable]
name     = ${CI_PROJECT_NAME} -- unstable RPMs
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/unstable/repos/${RELEASE_PLATFORM}/RPMS
enabled  = 0
gpgcheck = 0

[${CI_PROJECT_NAME}-unstable-sources]
name     = ${CI_PROJECT_NAME} -- unstable source RPMs
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/unstable/repos/SRPMS/${RELEASE_PLATFORM}
enabled  = 0
gpgcheck = 0

[${CI_PROJECT_NAME}-unstable-debug]
name     = ${CI_PROJECT_NAME} -- unstable debuginfo RPMS
baseurl  = ${EOS_SITE_URL}/sw/${CI_PROJECT_NAME}/unstable/repos/${RELEASE_PLATFORM}/DEBUGRPMS
enabled  = 0
gpgcheck = 0
EOF


