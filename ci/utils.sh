## Utility functions

authenticateKRB () {
    local KRB_PASSWORD=$(echo ${KRB_PASSWORD} | base64 -d)
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64 -d)
    echo ${KRB_PASSWORD} | kinit -A -f ${KRB_USERNAME}@CERN.CH
    # local KRB_PASSWORD=$(echo ${KRB_PASSWORD} | base64)
    # local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64)

    local SSHHOME=/tmp/.ssh
    mkdir -p ${SSHHOME}/tmp
    chmod go-rwx -R ${SSHHOME}
    touch ${SSHHOME}/config
    chmod go-rw ${SSHHOME}/config
    cat<<EOF>${SSHHOME}/config
ControlMaster             auto
ControlPersist            1000
ControlPath               ${SSHHOME}/tmp/master_%l_%h_%p_%r
ServerAliveInterval       30
HashKnownHosts            yes
StrictHostKeyChecking     no
GSSAPIAuthentication      yes
GSSAPITrustDNS            yes
GSSAPIDelegateCredentials yes
EOF
}

unauthenticateKRB () {
    kdestroy
    local SSHHOME=/tmp/.ssh
    if [ -d ${SSHHOME} ]
    then
        find ${SSHHOME} -type f -print0 -exec shred -n100 -u {} \;
    fi
}

## import GPG key
importGPG () {
    # export GNUPGHOME=/tmp/.gnupg-ci
    mkdir -p ${GNUPGHOME}
    # sudo mount -t ramfs -o size=1M ramfs ${GNUPGHOME}
    # sudo chown $(id -u):$(id -g) ${GNUPGHOME}
    chmod go-rwx ${GNUPGHOME}
    if [ -n ${GPG_SIGNING_KEY_PRIV} ]
    then
        if [ -f ${GPG_SIGNING_KEY_PRIV} ]
        then
            cat ${GPG_SIGNING_KEY_PRIV} | gpg -v --import
            #>& /dev/null
            # eval `gpg -v --import <(cat '${GPG_SIGNING_KEY_PRIV}')`
            #>& /dev/null
            ## process substitution broken for some reason...
            # gpg -v --import <(echo '${GPG_SIGNING_KEY_PRIV}')
        else
            echo ${GPG_SIGNING_KEY_PRIV} | gpg -v --import
            #>& /dev/null
            # eval `gpg -v --import <(echo '${GPG_SIGNING_KEY_PRIV}')`
            #>& /dev/null
            ## process substitution broken for some reason...
            # gpg -v --import <(cat '${GPG_SIGNING_KEY_PRIV}')
        fi
        gpg -k
    else
        echo No GPG key provided
        exit 1
    fi
    # unset GNUPGHOME
}

## remove imported GPG key
destroyGPG () {
    local GNUPGHOME=/tmp/.gnupg-ci
    if [ -d ${GNUPGHOME} ]
    then
        find ${GNUPGHOME} -type f -print0 -exec shred -n100 -u {} \;

        if [ "$(mount|egrep ${GNUPGHOME} >& /dev/null && echo $?)" = "0" ]
        then
            sudo umount ${GNUPGHOME}
        fi
        rm -rf ${GNUPGHOME}
    fi
}

cleanup () {
    unauthenticateKRB
    destroyGPG
}

## add GPG signature to RPM
signRPMs () (
    export GNUPGHOME=/tmp/.gnupg-ci
    importGPG
    echo Imported GPG chain for signing RPMs
    local GPG_PASSPHRASE=$(echo ${GPG_PASSPHRASE} | base64 -d)
    cat <<EOF > ~/.rpmmacros
%_signature gpg
%_gpg_name CMS GEM DAQ Project CI <gemdaq.ci@cern.ch>
EOF
    find ${ARTIFACTS_DIR}/repos -iname '*.rpm' -print0 -exec \
         sh -ec '(echo set timeout -1; \
echo spawn rpmsign --addsign {}; \
echo expect -exact \"Enter pass phrase:\"; \
echo send -- \"${GPG_PASSPHRASE}\\r\"; \
echo expect eof; ) | expect' \;
    local GPG_PASSPHRASE=$(echo ${GPG_PASSPHRASE} | base64)
    destroyGPG
    echo Destroyed GPG chain for signing RPMs
    unset GNUPGHOME
)

## create GPG signature for other tarballs
signTarballs () (
    export GNUPGHOME=/tmp/.gnupg-ci
    importGPG
    echo Imported GPG chain for signing tarballs
    local GPG_PASSPHRASE=$(echo ${GPG_PASSPHRASE} | base64 -d)
    find ${ARTIFACTS_DIR}/repos/tarballs -type f \
         \( -iname '*.zip' -o -iname '*.tgz' -o -iname '*.tbz2' \) \
         -print0 -exec \
         sh -ec 'echo ${GPG_PASSPHRASE} | gpg --batch --yes --passphrase-fd 0 --detach-sign --armor {}' \;
    local GPG_PASSPHRASE=$(echo ${GPG_PASSPHRASE} | base64)
    destroyGPG
    echo Destroyed GPG chain for signing tarballs
    unset GNUPGHOME
)

## add GPG signtaure to repository metadata
signRepository () {
    # set -o posix
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64 -d)
    local SSHHOME=/tmp/.ssh
    repofiles=()
    ## redirect to tmp file, as pipe doesn't work when called from script
    klist
    ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch <<EOF > tmpfiles
find ${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${CI_REPO_DIR} -type f -iname '*.xml' -print0
EOF
    while IFS=  read -r -d $'\0'
    do
        repofiles+=("$REPLY")
    done < tmpfiles
    ## process substitution broken for some reason...
    # done < <(ssh -t ${KRB_USERNAME}@lxplus.cern.ch "find ${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${DEPLOY_DIR} -type f -iname '*.xml' -print0")
    #rm tmpfiles

    export GNUPGHOME=/tmp/.gnupg-ci
    importGPG
    echo Imported GPG chain for signing repo metadata
    local GPG_PASSPHRASE=$(echo ${GPG_PASSPHRASE} | base64 -d)
    for f in ${repofiles[@]}
    do
        scp -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch:$f .
        echo ${GPG_PASSPHRASE} | gpg --batch --yes --passphrase-fd 0 --detach-sign -a $(basename $f)
        ls -l $(basename $f)*
        scp -F ${SSHHOME}/config $(basename $f)* ${KRB_USERNAME}@lxplus.cern.ch:${f%%$(basename $f)}
        shred -n100 -u $(basename $f)
        shred -n100 -u $(basename $f).asc
    done

    local GPG_PASSPHRASE=$(echo ${GPG_PASSPHRASE} | base64)
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64)
    destroyGPG
    echo Destroyed GPG chain for signing repo metadata
    unset GNUPGHOME
}

publishRepository () {
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64 -d)
    local SSHHOME=/tmp/.ssh
    pushd ${ARTIFACTS_DIR}/repos
    rsync -e "ssh -F ${SSHHOME}/config" -ahcX \
          --chmod=go-w \
          --relative . --exclude=*.repo \
          --rsync-path="mkdir -p ${EOS_REPO_PATH} && rsync" ${KRB_USERNAME}@lxplus.cern.ch:${EOS_REPO_PATH}
    popd

    echo "Updating the repositories"
    find ${ARTIFACTS_DIR}/repos -iname '*.repo' -print0 -exec \
         sed -i "s|\${EOS_SITE_URL}|${EOS_SITE_URL}|g" {} \+
    rsync -e "ssh -F ${SSHHOME}/config" -ahcX \
          --chmod=go-w \
          ${ARTIFACTS_DIR}/repos/*.repo ${KRB_USERNAME}@lxplus.cern.ch:${EOS_SW_PATH}/repos

    ## update the groups files?

    ## update the repositories
    klist
    ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch <<EOF
find ${EOS_REPO_PATH} -type d -name '*RPMS' -print0 -exec createrepo --update {} \;
EOF

    ## signRepository also decodes this, so have to revert as the local variable will be passed
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64)
    signRepository
}

publishDocs () {
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64 -d)
    local SSHHOME=/tmp/.ssh
    LATEST_DOC_DIR=${EOS_BASE_WEB_DIR}/${EOS_DOCS_DIR}

    klist
    if [[ "$1" =~ "unstable" ]]
    then
        echo "Publishing unstable docs"
        ## we are on an unstable version
        TAG_DOC_DIR=${CI_DOCS_DIR}
        CI_TAG_DOC_DIR=${EOS_DOCS_PATH}/${CI_PROJECT_NAME}/${TAG_DOC_DIR}
        rsync -e "ssh -F ${SSHHOME}/config" -ahcX \
              --chmod=go-w \
              --rsync-path="mkdir -p ${CI_TAG_DOC_DIR} && rsync" . --delete ${KRB_USERNAME}@lxplus.cern.ch:${CI_TAG_DOC_DIR}
#         ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch "/bin/bash" <<EOF
# mkdir -p ${LATEST_DOC_DIR};
# ln -sfn ../../${EOS_SW_DIR}/${TAG_DOC_DIR} ${LATEST_DOC_DIR}/unstable
# EOF
    elif [[ "$1" =~ "testing" ]]
    then
        echo "Publishing testing docs"
        ## X.Y prerelease (package in testing)
        TAG_DOC_DIR=${CI_DOCS_DIR}/latest
        CI_TAG_DOC_DIR=${EOS_DOCS_PATH}/${CI_PROJECT_NAME}/${TAG_DOC_DIR}
        rsync -e "ssh -F ${SSHHOME}/config" -ahcX \
              --chmod=go-w \
              --rsync-path="mkdir -p ${CI_TAG_DOC_DIR} && rsync" . --delete ${KRB_USERNAME}@lxplus.cern.ch:${CI_TAG_DOC_DIR}
#         ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch "/bin/bash" <<EOF
# mkdir -p ${LATEST_DOC_DIR};
# ln -sfn ../../${EOS_SW_DIR}/${TAG_DOC_DIR} ${LATEST_DOC_DIR}/latest;
# EOF
    elif [[ "$1" =~ "base" ]]
    then
        echo "Publishing base docs"
        ## X.Y.Z version (package in base)
        TAG_DOC_DIR=${CI_DOCS_DIR}/${BUILD_VER}
        CI_TAG_DOC_DIR=${EOS_DOCS_PATH}/${CI_PROJECT_NAME}/${TAG_DOC_DIR}
        LATEST_TAG_DOC_DIR=${CI_DOCS_DIR}/latest
        rsync -e "ssh -F ${SSHHOME}/config" -ahcX \
              --chmod=go-w \
              --rsync-path="mkdir -p ${CI_TAG_DOC_DIR} && rsync" . --delete ${KRB_USERNAME}@lxplus.cern.ch:${CI_TAG_DOC_DIR}
#         ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch "/bin/bash" <<EOF
# mkdir -p ${LATEST_TAG_DOC_DIR};
# rsync -ahcX ${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${TAG_DOC_DIR}/ ${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${LATEST_TAG_DOC_DIR};
# mkdir -p ${LATEST_DOC_DIR};
# ln -sfn ../../${EOS_SW_DIR}/${LATEST_TAG_DOC_DIR} ${LATEST_DOC_DIR}/latest
# EOF
    fi
    ## update the index file?
    ## or have the landing page running some scripts querying the git tags, populating some JSON, and dynamically adapting the content
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64)
}

CONFIG_DIR=$(dirname $0)/..
if [ "${CONFIG_DIR}" = "./.." ]
then
    CONFIG_DIR=$(dirname "$BASH_SOURCE[0]")/..
fi

if ! [ -f ${CONFIG_DIR}/ci/utils.sh ]
then
    echo "Unable to obtain directory, exiting"
    exit 1
fi

## Common regex strings
# repo release is X.Y, independent of package tag version
rre='^([0-9]+)\.([0-9]+)$'
# basic package version unit is vX.Y.Z
vre='^v?(\.)?([0-9]+)\.([0-9]+)\.([0-9]+)'
gre='(git[0-9a-fA-F]{6,8})'
relre='(^release/gemos-[0-9]+\.[0-9]+$)'

## Common variables
BUILD_VER=$(${CONFIG_DIR}/tag2rel.sh | \
                   awk '{split($$0,a," "); print a[5];}' | \
                   awk '{split($$0,b,":"); print b[2];}')
BUILD_TAG=$(${CONFIG_DIR}/tag2rel.sh | \
                   awk '{split($$0,a," "); print a[8];}' | \
                   awk '{split($$0,b,":"); print b[2];}')

# ## because CI_COMMIT_REF_NAME is *either* the branch *or* the tag of the running job
## with this we could get multiple hits
# BRANCH_NAME=$(git branch --contains ${CI_COMMIT_REF_NAME})
## with this we run the risk that a new push invalidates this variable
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

if [[ ${BRANCH_NAME} =~ HEAD ]]
then
    BRANCH_NAME=$(git branch -vvr | egrep $(git rev-parse --short HEAD))
    BRANCH_NAME=$(echo ${BRANCH_NAME#*origin/} | awk '{split($$0,a," "); print a[1];}')
fi

if [[ "${BRANCH_NAME}" =~ ${relre} ]]
then
    REL_VERSION=${BRANCH_NAME##*/}
    REL_VERSION=${REL_VERSION##*-}
else
    REL_VERSION=unstable-PKG-${BUILD_VER%.*}
fi

echo BRANCH_NAME is ${BRANCH_NAME}
echo REL_VERSION is ${REL_VERSION}
echo BUILD_VER is ${BUILD_VER}
echo BUILD_TAG is ${BUILD_TAG}
