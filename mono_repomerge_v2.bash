#!/bin/bash

set -euo pipefail

###############################################################################

Usage

./combine_repos.sh \

git@gitlab.company.com:team/A.git \

git@gitlab.company.com:team/B.git \

git@gitlab.company.com:team/C.git

###############################################################################

ROOT_DIR=”$(pwd)”
COMBINED_REPO=”$ROOT_DIR/combined_repo”
FIRST_DEFAULT_BRANCH=””

usage()
{
echo
echo “Usage:”
echo “  $0  [repo2] [repo3] …”
echo
exit 1
}

cleanup()
{
rm -rf “$COMBINED_REPO”
mkdir -p “$COMBINED_REPO”
}

create_monorepo()
{
cd “$COMBINED_REPO”

git init
git commit \
    --allow-empty \
    -m "Initial monorepo commit"

}

get_default_branch()
{
local remote_name=”$1”

git remote show "$remote_name" |
    sed -n '/HEAD branch/s/.*: //p'

}

add_remote()
{
local repo_name=”$1”
local repo_url=”$2”

if ! git remote | grep -qx "$repo_name"; then
    git remote add "$repo_name" "$repo_url"
fi

}

fetch_repository()
{
local repo_name=”$1”

echo "Fetching branches..."
git fetch "$repo_name" \
    '+refs/heads/*:refs/remotes/'"$repo_name"'/*'
echo "Fetching tags..."
git fetch "$repo_name" \
    '+refs/tags/*:refs/tags/*' \
    --force

}

initialize_default_branch()
{
local default_branch=”$1”

if [ -z "$FIRST_DEFAULT_BRANCH" ]; then
    FIRST_DEFAULT_BRANCH="$default_branch"
    git checkout -B "$FIRST_DEFAULT_BRANCH"
fi

}

import_repository()
{
local repo_name=”$1”
local default_branch=”$2”

git subtree add \
    --prefix="$repo_name" \
    "$repo_name" \
    "$default_branch" \
    -m "Import $repo_name"

}

process_repository()
{
local repo_url=”$1”
local repo_name
local default_branch

repo_name=$(basename "$repo_url" .git)
echo
echo "=================================================="
echo "IMPORTING $repo_name"
echo "=================================================="
echo
add_remote "$repo_name" "$repo_url"
fetch_repository "$repo_name"
default_branch=$(get_default_branch "$repo_name")
if [ -z "$default_branch" ]; then
    echo "ERROR: Could not determine default branch for $repo_name"
    exit 1
fi
echo "Default branch: $default_branch"
initialize_default_branch "$default_branch"
import_repository "$repo_name" "$default_branch"

}

create_branch_references()
{
echo
echo “==================================================”
echo “CREATING BRANCH REFERENCES”
echo “==================================================”
echo

git for-each-ref \
    --format='%(refname:short)' \
    refs/remotes |
while read -r remote_ref
do
    case "$remote_ref" in
        */HEAD)
            continue
            ;;
    esac
    repo_name=$(echo "$remote_ref" | cut -d/ -f1)
    branch_name=$(echo "$remote_ref" | cut -d/ -f2-)
    local_branch="${branch_name}_${repo_name}"
    echo "Creating branch: $local_branch"
    git branch \
        -f \
        "$local_branch" \
        "$remote_ref"
done

}

print_summary()
{
echo
echo “==================================================”
echo “DONE”
echo “==================================================”

echo
echo "Current branch:"
git branch
echo
echo "Remote branches:"
git branch -r
echo
echo "Tags:"
git tag
echo
echo "History:"
echo "  git log --graph --oneline --all"
echo
echo "Repository:"
echo "  $COMBINED_REPO"
echo
echo "Push example:"
echo
echo "  cd combined_repo"
echo "  git remote add origin git@gitlab.company.com:team/osi_single.git"
echo "  git push -u origin $FIRST_DEFAULT_BRANCH"
echo "  git push origin --all"
echo "  git push origin --tags"

}

main()
{
[ “$#” -lt 1 ] && usage

cleanup
create_monorepo
for repo_url in "$@"
do
    process_repository "$repo_url"
done
create_branch_references
print_summary

}

main “$@”
