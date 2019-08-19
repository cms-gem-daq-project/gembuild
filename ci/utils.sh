## Utility functions

authenticateKRB () {
    local KRB_PASSWORD=$(echo ${KRB_PASSWORD} | base64 -d)
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64 -d)
    echo ${KRB_PASSWORD} | kinit -A -f ${KRB_USERNAME}@CERN.CH
    local KRB_PASSWORD=$(echo ${KRB_PASSWORD} | base64)
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64)

    export SSHHOME=/tmp/.ssh
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
    export SSHHOME=/tmp/.ssh
    if [ -d ${SSHHOME} ]
    then
        find ${SSHHOME} -type f -print0 -exec shred -n100 -u {} \;
    fi
    unset SSHHOME
}

## import GPG key
importGPG () {
    export GNUPGHOME=/tmp/.gnupg-ci
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
    unset GNUPGHOME
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
)

## create GPG signature for other tarballs
signTarballs () (
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
)

## add GPG signtaure to repository metadata
signRepository () {
    # set -o posix
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64 -d)
    repofiles=()
    ## redirect to tmp file, as pipe doesn't work when called from script
    klist
    ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch <<EOF > tmpfiles
find ${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${DEPLOY_DIR} -type f -iname '*.xml' -print0
EOF
    while IFS=  read -r -d $'\0'
    do
        repofiles+=("$REPLY")
    done < tmpfiles
    ## process substitution broken for some reason...
    # done < <(ssh -t ${KRB_USERNAME}@lxplus.cern.ch "find ${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${DEPLOY_DIR} -type f -iname '*.xml' -print0")
    #rm tmpfiles

    importGPG
    echo Imported GPG chain for signing repo metadata
    local GPG_PASSPHRASE=$(echo ${GPG_PASSPHRASE} | base64 -d)
    for f in ${repofiles[@]}
    do
        scp ${KRB_USERNAME}@lxplus.cern.ch:$f .
        echo ${GPG_PASSPHRASE} | gpg --batch --yes --passphrase-fd 0 --detach-sign -a $(basename $f)
        ls -l $(basename $f)*
        scp $(basename $f)* ${KRB_USERNAME}@lxplus.cern.ch:${f%%$(basename $f)}
        shred -n100 -u $(basename $f)
        shred -n100 -u $(basename $f).asc
    done

    local GPG_PASSPHRASE=$(echo ${GPG_PASSPHRASE} | base64)
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64)
    destroyGPG
    echo Destroyed GPG chain for signing repo metadata
}

publishRepository () {
    local KRB_USERNAME=$(echo ${KRB_USERNAME} | base64 -d)
    pushd ${ARTIFACTS_DIR}/repos
    rsync -ahcX --relative . --exclude=*.repo \
          --rsync-path="mkdir -p ${EOS_REPO_PATH} && rsync" ${KRB_USERNAME}@lxplus.cern.ch:${EOS_REPO_PATH}
    popd

    echo "Updating the repositories"
    rsync -ahcX \
          ${ARTIFACTS_DIR}/repos/*.repo ${KRB_USERNAME}@lxplus.cern.ch:${EOS_SW_PATH}

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
    LATEST_DOC_DIR=${EOS_BASE_WEB_DIR}/${EOS_DOCS_DIR}

    klist
    if [[ "$1" =~ "unstable" ]]
    then
        echo "Publishing unstable docs"
        ## we are on an unstable version
        TAG_DOC_DIR=${CI_DOCS_DIR}
        CI_TAG_DOC_DIR=${EOS_SW_PATH}/${CI_PROJECT_NAME}/${TAG_DOC_DIR}
        rsync -ahcX \
              --rsync-path="mkdir -p ${CI_TAG_DOC_DIR} && rsync" . --delete ${KRB_USERNAME}@lxplus.cern.ch:${CI_TAG_DOC_DIR}
        ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch "/bin/bash" <<EOF
mkdir -p ${LATEST_DOC_DIR};
ln -sfn ../../${EOS_SW_DIR}/${TAG_DOC_DIR} ${LATEST_DOC_DIR}/unstable
EOF
    elif [[ "$1" =~ "testing" ]]
    then
        echo "Publishing testing docs"
        ## X.Y prerelease (package in testing)
        TAG_DOC_DIR=${CI_DOCS_DIR}/latest
        CI_TAG_DOC_DIR=${EOS_SW_PATH}/${CI_PROJECT_NAME}/${TAG_DOC_DIR}
        rsync -ahcX \
              --rsync-path="mkdir -p ${CI_TAG_DOC_DIR} && rsync" . --delete ${KRB_USERNAME}@lxplus.cern.ch:${CI_TAG_DOC_DIR}
        ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch "/bin/bash" <<EOF
mkdir -p ${LATEST_DOC_DIR};
ln -sfn ../../${EOS_SW_DIR}/${TAG_DOC_DIR} ${LATEST_DOC_DIR}/latest;
EOF
    elif [[ "$1" =~ "base" ]]
    then
        echo "Publishing base docs"
        ## X.Y.Z version (package in base)
        TAG_DOC_DIR=${CI_DOCS_DIR}/${BUILD_VER}
        CI_TAG_DOC_DIR=${EOS_SW_PATH}/${CI_PROJECT_NAME}/${TAG_DOC_DIR}
        LATEST_TAG_DOC_DIR=${CI_DOCS_DIR}/latest
        rsync -ahcX \
              --rsync-path="mkdir -p ${CI_TAG_DOC_DIR} && rsync" . --delete ${KRB_USERNAME}@lxplus.cern.ch:${CI_TAG_DOC_DIR}
        ssh -F ${SSHHOME}/config ${KRB_USERNAME}@lxplus.cern.ch "/bin/bash" <<EOF
mkdir -p ${LATEST_TAG_DOC_DIR};
rsync -ahcX ${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${TAG_DOC_DIR}/ ${EOS_BASE_WEB_DIR}/${EOS_SW_DIR}/${LATEST_TAG_DOC_DIR};
mkdir -p ${LATEST_DOC_DIR};
ln -sfn ../../${EOS_SW_DIR}/${LATEST_TAG_DOC_DIR} ${LATEST_DOC_DIR}/latest
EOF
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

BUILD_VER=$(${CONFIG_DIR}/tag2rel.sh | \
                   awk '{split($$0,a," "); print a[5];}' | \
                   awk '{split($$0,b,":"); print b[2];}')
BUILD_TAG=$(${CONFIG_DIR}/tag2rel.sh | \
                   awk '{split($$0,a," "); print a[8];}' | \
                   awk '{split($$0,b,":"); print b[2];}')

REL_VERSION=${BUILD_VER%.*}

## Would like to have a single gemos repo, with some "release" version, but requires
#  that all packages are tracked and maintained in concert, and adds compleity without
#  clear path to maintainability -- future enhancement to extract the gemos release
#  from the branch name, and follow a strict procedure for creating releases
# ## because CI_COMMIT_REF_NAME is either the branch or the tag of the job
# CI_BRANCH_NAME=$(git branch --contains ${CI_COMMIT_REF_NAME})
# REL_VERSION=${CI_BRANCH_NAME##*/}
