#!/bin/sh -eu

source $(dirname $0)/utils.sh

trap cleanup SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

## Structure of ARTIFACTS_DIR
# └── artifacts
#     ├── api
#     └── repos
#         ├── ${CI_PROJECT_NAME}_${REL_VERSION}_{ARCH}.repo
#         ├── SRPMS ## should be arch independent...
#         └── ${ARCH}/{'','base','testing'}
#             ├── tarballs
#             ├── RPMS
#             ├── DEBUGRPMS
#             └── SRPMS ## should be arch independent...

## from https://gist.github.com/jsturdy/a9cbc64c947364a01057a1d40e228452
# ├── index.html
# ├── sw
# │   ├── RPM-GPG-KEY-cmsgemdaq
# │   ├── ${CI_PROJECT_NAME}_${REL_VERSION}_{ARCH}.repo (or in the ${CI_PROJECT_NAME} namespace?
# │   ├── ${CI_PROJECT_NAME}
# │   │   ├── ${CI_PROJECT_NAME}_${REL_VERSION}_{ARCH}.repo
# │   │   ├── unstable (${EOS_UNSTABLE_DIR}) ## all builds not on a release branch
# │   │   │   ├── api (${EOS_DOC_NAME})
# │   │   │   │   └── latest ## overwrite with latest each build
# │   │   │   └── repos (${EOS_REPO_NAME})
# │   │   │       ├── SRPMS ## should be arch independent
# │   │   │       │   └── repodata
# │   │   │       └── ${ARCH} ## (slc6_x86_64/centos7_x86_64/centos8_x86_64/arm/peta/noarch/pythonX.Y/gccXYZ/clangXYZ?)
# │   │   │           ├── tarballs
# │   │   │           ├── RPMS  ## keep all versions, manual cleanup only?
# │   │   │           │   └── repodata
# │   │   │           └── DEBUGRPMS
# │   │   │               └── repodata
# │   │   └── releases (${EOS_RELEASE_DIR})
# │   │       ├── api (${EOS_DOC_NAME})
# │   │       │   ├── latest (symlink to the very latest api version build?)
# │   │       │   └── ${REL_VERSION} ## Maj.Min, might even not have this directory?
# │   │       │       ├── latest -> ${REL_VERSION}.Z+2
# │   │       │       ├── ${REL_VERSION}.Z+2
# │   │       │       ├── ${REL_VERSION}.Z+1
# │   │       │       └── ${REL_VERSION}.Z
# │   │       └── repos (${EOS_REPO_NAME})
# │   │           └── ${REL_VERSION} ## Maj.Min
# │   │               ├── base
# │   │               │   ├── SRPMS ## should be arch independent
# │   │               │   │   └── repodata
# │   │               │   └── ${ARCH} ## (slc6_x86_64/centos7_x86_64/centos8_x86_64/arm/peta/noarch/pythonX.Y/gccXYZ/clangXYZ?)
# │   │               │       ├── tarballs
# │   │               │       ├── RPMS
# │   │               │       │   └── repodata
# │   │               │       └── DEBUGRPMS
# │   │               │           └── repodata
# │   │               └── testing ## all untagged builds along a given release tree
# │   │                   ├── SRPMS ## should be arch independent
# │   │                   │   └── repodata
# │   │                   └── ${ARCH} ## (slc6_x86_64/centos7_x86_64/centos8_x86_64/arm/peta/noarch/pythonX.Y/gccXYZ/clangXYZ?)
# │   │                       ├── tarballs
# │   │                       ├── RPMS
# │   │                       │   └── repodata
# │   │                       └── DEBUGRPMS
# │   │                           └── repodata
############### BEGIN OR
# │   │   └── releases (${EOS_RELEASE_DIR})
# │   │       └── ${REL_VERSION} ## Maj.Min
# │   │           ├── api (${EOS_DOC_NAME})
# │   │           │   ├── latest -> ${REL_VERSION}.Z+2
# │   │           │   ├── ${REL_VERSION}.Z+2
# │   │           │   ├── ${REL_VERSION}.Z+1
# │   │           │   └── ${REL_VERSION}.Z
# │   │           └── repos (${EOS_REPO_NAME})
# │   │               ├── base
# │   │               │   └── ${ARCH} ## (slc6_x86_64/centos7_x86_64/centos8_x86_64/arm/peta/noarch/pythonX.Y/gccXYZ/clangXYZ?)
# │   │               │       ├── tarballs
# │   │               │       ├── RPMS
# │   │               │       │   └── repodata
# │   │               │       └── DEBUGRPMS
# │   │               │           └── repodata
# │   │               └── testing ## all untagged builds along a given release tree
# │   │                   └── ${ARCH} ## (slc6_x86_64/centos7_x86_64/centos8_x86_64/arm/peta/noarch/pythonX.Y/gccXYZ/clangXYZ?)
# │   │                       ├── tarballs
# │   │                       ├── RPMS
# │   │                       │   └── repodata
# │   │                       └── DEBUGRPMS
# │   │                           └── repodata
# │   └── extras ## holds all extra/external packages we build for compatibility
# │       ├── SRPMS ## provide source RPMs for extras?
# │       │   └── repodata
# |       └── ${ARCH} ## (slc6_x86_64/centos7_x86_64/centos8_x86_64/arm/peta/noarch/pythonX.Y/gccXYZ/clangXYZ?)
# │           ├── RPMS
# │           │   └── repodata
# │           └── DEBUGRPMS
# │               └── repodata
# ├── guides ## user/developer guides and other synthesied information, if versioning of this is foreseen, need to address
# │   ├── user
# |   │   └── index.html
# │   └── developers
# |       └── index.html
# └── docs
#     ├── index.html
#     └── ${CI_PROJECT_NAME} ## one for each repo, this would be he entry point to the versioned
#         ├── index.html
#         ├── unstable ## filled from `develop` or symlink to the above `api/latest`
#         ├── latest ## filled from last tagged build, or as a symlink to releases/M.M/api/latest
#         └── styles/scripts/css/js  ## styles that we will not change

RELEASE_DIR=${EOS_RELEASE_DIR}/${REL_VERSION}

BASE_DIR=${PWD}

##### RPMs
# repo release is X.Y, independent of package tag version
rre='^([0-9]+)\.([0-9]+)$'
# basic package version unit is vX.Y.Z
vre='^v?(\.)?([0-9]+)\.([0-9]+)\.([0-9]+)'
gre='(git[0-9a-fA-F]{6,8})'

## map source dir to output dir
echo "Figuring out appropriate tag"
## choose the correct of: base|testing|unstable
if [[ ${BUILD_TAG} =~ (dev) ]] || [[ ${CI_COMMIT_REF_NAME} =~ (develop) ]] 
then
    ## unstable for dev tag or 'develop' branch
    DEPLOY_DIR=${EOS_UNSTABLE_DIR}
    TAG_REPO_TYPE=/unstable
elif [[ ${BUILD_VER}${BUILD_TAG} =~ $vre-final$ ]] &&  [[ ${CI_COMMIT_REF_NAME} =~ (^(master$|release/)) ]]
then
    ## base for tag vX.Y.Z
    DEPLOY_DIR=${EOS_RELEASE_DIR}/${REL_VERSION}
    TAG_REPO_TYPE=base/base
elif [[ ${BUILD_TAG} =~ (alpha|beta|pre|rc) ]] || [[ ${CI_COMMIT_REF_NAME} =~ (^release) ]]
then
    ## testing for tag vX.Y.Z-(alpha|beta|pre|rc)\d+-git<hash> or untagged on release/*
    DEPLOY_DIR=${EOS_RELEASE_DIR}/${REL_VERSION}
    TAG_REPO_TYPE=testing/testing
else
    ## unstable for unknown or untagged
    DEPLOY_DIR=${EOS_UNSTABLE_DIR}
    TAG_REPO_TYPE=/unstable
fi

CI_DOCS_DIR=${DEPLOY_DIR}/${EOS_DOC_NAME}
CI_REPO_DIR=${DEPLOY_DIR}/${EOS_REPO_NAME}

EOS_REPO_PATH=${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${CI_REPO_DIR}/${TAG_REPO_TYPE%%/*}

EOS_SW_PATH=${EOS_BASE_WEB_DIR}/${EOS_SW_DIR%%/${CI_PROJECT_NAME}}
EOS_DOCS_PATH=${EOS_BASE_WEB_DIR}/${EOS_DOCS_DIR%%/${CI_PROJECT_NAME}}

echo "Tag ${BUILD_VER}${BUILD_TAG} determined to be ${TAG_REPO_TYPE#*/}"

signRPMs
echo Signed RPMs

signTarballs
echo Signed tarballs

KRB_CACHE=$(klist |egrep FILE| awk '{split($0,a, " "); print a[3];}')
authenticateKRB

publishRepository

##### Documentation, only done for final tags?
echo "Publishing documentation for ${BUILD_TAG}"
pushd ${ARTIFACTS_DIR}/api

if [ -n "${BUILD_TAG}" ]
then
    ## we are on a release X.Y version
    if [[ ${BUILD_TAG} =~ (dev) ]] || [[ ${CI_COMMIT_REF_NAME} =~ (develop) ]] 
    then
        publishDocs "unstable"
    elif [[ "${BUILD_TAG}" =~ -final$ ]] &&  [[ ${CI_COMMIT_REF_NAME} =~ (^(master$|release/)) ]]
    then
        publishDocs "base"
    elif [[ ${BUILD_TAG} =~ (alpha|beta|pre|rc) ]] || [[ ${CI_COMMIT_REF_NAME} =~ (^release) ]]
    then
        publishDocs "testing"
    else
        publishDocs "unstable"
    fi
fi

popd

unauthenticateKRB

if [ -n ${KRB_CACHE} ] && [ -f ${KRB_CACHE##'FILE:'} ]
then
    export KRB5CCNAME=${KRB_CACHE}
    krenew
fi
