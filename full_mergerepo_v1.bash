#!/bin/bash

set -e

###############################################################################

Usage

./combine_repos.sh \

git@gitlab.company.com:team/A.git \

git@gitlab.company.com:team/B.git \

git@gitlab.company.com:team/C.git

###############################################################################

if [ “$#” -lt 1 ]; then
echo
echo “Usage:”
echo “  $0  [repo2] [repo3] …”
echo
exit 1
fi

###############################################################################

Configuration

###############################################################################

DEFAULT_BRANCH=“rsg_develop”

ROOT_DIR=”$(pwd)”
COMBINED_REPO=”$ROOT_DIR/combined_repo”

###############################################################################

Cleanup

###############################################################################

rm -rf “$COMBINED_REPO”

mkdir -p “$COMBINED_REPO”

###############################################################################

Create monorepo

###############################################################################

cd “$COMBINED_REPO”

git init

git checkout -b “$DEFAULT_BRANCH”

git commit 
–allow-empty 
-m “Initial monorepo commit”

###############################################################################

Import repositories

###############################################################################

for REPO_URL in “$@”
do

REPO_NAME=$(basename "$REPO_URL" .git)
echo
echo "=================================================="
echo "IMPORTING $REPO_NAME"
echo "=================================================="
echo
###########################################################################
# Add remote
###########################################################################
if ! git remote | grep -qx "$REPO_NAME"; then
    git remote add \
        "$REPO_NAME" \
        "$REPO_URL"
fi
###########################################################################
# Fetch ALL branches
###########################################################################
git fetch "$REPO_NAME" \
    '+refs/heads/*:refs/remotes/'"$REPO_NAME"'/*'
###########################################################################
# Fetch ALL tags
#
# Latest fetched repo wins if tags collide
###########################################################################
git fetch "$REPO_NAME" \
    '+refs/tags/*:refs/tags/*' \
    --force
###########################################################################
# Import default branch into folder
###########################################################################
git subtree add \
    --prefix="$REPO_NAME" \
    "$REPO_NAME" \
    "$DEFAULT_BRANCH" \
    -m "Import $REPO_NAME"

done

###############################################################################

Create local branches for all remote branches

###############################################################################

echo
echo “==================================================”
echo “CREATING BRANCH REFERENCES”
echo “==================================================”
echo

for REMOTE_REF in $(
git for-each-ref 
–format=’%(refname:short)’ 
refs/remotes
)
do

case "$REMOTE_REF" in
    */HEAD)
        continue
        ;;
esac
REPO_NAME=$(echo "$REMOTE_REF" | cut -d/ -f1)
BRANCH_NAME=$(echo "$REMOTE_REF" | cut -d/ -f2-)
LOCAL_BRANCH="${BRANCH_NAME}_${REPO_NAME}"
echo "Creating branch: $LOCAL_BRANCH"
git branch \
    -f \
    "$LOCAL_BRANCH" \
    "$REMOTE_REF"

done

###############################################################################

Summary

###############################################################################

echo
echo “==================================================”
echo “DONE”
echo “==================================================”
echo

echo “Current branch:”
git branch

echo
echo “Remote branches:”
git branch -r

echo
echo “Tags:”
git tag

echo
echo “History:”
echo “  git log –graph –oneline –all”

echo
echo “Repository:”
echo “  $COMBINED_REPO”
echo

echo “Push example:”
echo
echo “  cd combined_repo”
echo “  git remote add origin git@gitlab.company.com:team/osi_single.git”
echo “  git push -u origin rsg_develop”
echo “  git push origin –all”
echo “  git push origin –tags”
echo
