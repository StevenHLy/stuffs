#!/bin/bash

set -e

###############################################################################

Functions

###############################################################################

log_header()
{
echo
echo “==================================================”
echo “$1”
echo “==================================================”
echo
}

validate_args()
{
if [ “$#” -lt 1 ]; then
echo
echo “Usage:”
echo “  $0  [repo2] [repo3] …”
echo
exit 1
fi
}

init_repo()
{
rm -rf “$COMBINED_REPO”

mkdir -p "$COMBINED_REPO"
cd "$COMBINED_REPO"
git init
git commit \
    --allow-empty \
    -m "Initial combined repository"

}

add_remote()
{
local REPO_NAME=”$1”
local REPO_URL=”$2”

git remote add \
    "$REPO_NAME" \
    "$REPO_URL"
###########################################################################
# Fetch all branches
###########################################################################
git fetch "$REPO_NAME" \
    '+refs/heads/*:refs/remotes/'"$REPO_NAME"'/*'
###########################################################################
# Fetch all tags
###########################################################################
git fetch "$REPO_NAME" --tags

}

create_local_branches()
{
local REPO_NAME=”$1”

git for-each-ref \
    --format='%(refname:short)' \
    "refs/remotes/$REPO_NAME" |
while read REMOTE_BRANCH
do
    BRANCH_NAME=${REMOTE_BRANCH#"$REPO_NAME/"}
    [ "$BRANCH_NAME" = "HEAD" ] && continue
    #######################################################################
    # Keep original branch name if available
    #######################################################################
    if git show-ref \
        --verify \
        --quiet \
        "refs/heads/$BRANCH_NAME"
    then
        LOCAL_BRANCH="${BRANCH_NAME}_${REPO_NAME}"
    else
        LOCAL_BRANCH="${BRANCH_NAME}"
    fi
    echo "Creating branch: $LOCAL_BRANCH"
    git branch \
        -f \
        "$LOCAL_BRANCH" \
        "$REMOTE_BRANCH"
done

}

###############################################################################

Main

###############################################################################

validate_args “$@”

ROOT_DIR=”$(pwd)”
COMBINED_REPO=”$ROOT_DIR/combined_repo”

init_repo

for REPO_URL in “$@”
do

REPO_NAME=$(basename "$REPO_URL" .git)
log_header "PROCESSING: $REPO_NAME"
add_remote \
    "$REPO_NAME" \
    "$REPO_URL"
create_local_branches \
    "$REPO_NAME"

done

###############################################################################

Summary

###############################################################################

log_header “DONE”

echo “Remotes:”
git remote

echo
echo “Local branches:”
git branch

echo
echo “Remote branches:”
git branch -r

echo
echo “Tags:”
git tag

echo
echo “View all history:”
echo “  git log –graph –oneline –all”
echo
