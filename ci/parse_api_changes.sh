#!/bin/sh -eu

## Only runs on merge requests, easy
# TARGET_BRANCH=${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}
# SHARED_COMMIT=${CI_MERGE_REQUEST_TARGET_BRANCH_SHA}

## Run on every commit, manually, or on tags, more difficult
# SHARED_COMMIT=$(git merge-base ${TARGET_BRANCH} HEAD)

makeABIDump ()
{
    set -x
    if ! [ -n "$1" ]
    then
        echo ERROR: missing required branch argument
        exit 1
    elif ! [ -n "$2" ]
    then
        echo ERROR: missing required hash argument
        exit 1
    fi

    branch=$1
    githash=$2

    outdir=${CI_BUILDS_DIR}/abi-checking/${githash}
    mkdir -p ${outdir}

    git checkout ${branch}
    make clean
    OPTFLAGS="-g -Og" make -j8
    
    find . -iname '*.so' -print0 -exec abi-dumper {} -o ${outdir}/{}.dump -lver ${githash} \;
    set +x
}

checkABI()
{
    set -x
    if ! [ -n "$1" ]
    then
        echo ERROR: missing required library argument
        exit 1
    elif ! [ -n "$2" ]
    then
        echo ERROR: missing required output directory argument
        exit 1
    elif ! [ -n "$3" ]
    then
        echo ERROR: missing required old hash argument
        exit 1
    elif ! [ -n "$4" ]
    then
        echo ERROR: missing required new hash argument
        exit 1
    fi

    libobj=$1
    outdir=$2
    oldsha=$3
    newsha=$4

    libname=${libobj##*/}
    echo "Report for ${libobj}:" >> report.txt
    abi-compliance-checker -l ${libname} -old ${outdir}/${oldsha}/${libobj}.dump -new ${outdir}/${newsha}/${libobj}.dump | tee -a report.txt

    ## Sample output format
    # Preparing, please wait ...
    # Comparing ABIs ...
    # Comparing APIs ...
    # Creating compatibility report ...
    # Binary compatibility: 99.5%
    # Source compatibility: 99.7%
    # Total binary compatibility problems: 2, warnings: 0
    # Total source compatibility problems: 2, warnings: 0
    set +x
}

############################################################################################################################
# if ! [ $(git checkout -b new-abi ${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA} >& /dev/null) ]
if ! [ $(git checkout -b new-abi origin/${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME} >& /dev/null) ]
then
    echo Unable to create new branch new-abi
fi

#branchname=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
git checkout new-abi
CI_MERGE_REQUEST_SOURCE_BRANCH_SHA=$(git rev-parse --short HEAD 2>/dev/null)

# if ! [ $(git checkout -b old-abi ${CI_MERGE_REQUEST_TARGET_BRANCH_SHA} >& /dev/null) ]
if ! [ $(git checkout -b old-abi origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME} >& /dev/null) ]
then
    echo Unable to create new branch old-abi
fi

git checkout old-abi
CI_MERGE_REQUEST_TARGET_BRANCH_SHA=$(git rev-parse --short HEAD 2>/dev/null)

makeABIDump new-abi ${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA}
makeABIDump old-abi ${CI_MERGE_REQUEST_TARGET_BRANCH_SHA}

find . -iname '*.so' -print0 > libnames
libraries=()
while IFS=  read -r -d $'\0'
do
    libraries+=("$REPLY")
done < libnames

for lib in ${libraries[@]}
do
    checkABI ${lib} ${CI_BUILDS_DIR}/abi-checking ${CI_MERGE_REQUEST_TARGET_BRANCH_SHA} ${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA}
done

mv report.txt compat_reports
# tar cjf ${CI_MERGE_REQUEST_ID}.tbz2 compat_reports
