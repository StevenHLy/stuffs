#!/bin/bash

set -euo pipefail

ROOT_DIR=”$(pwd)”
COMBINED_REPO=”$ROOT_DIR/combined_repo”

COMBINED_BRANCH=””

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

create_repo()
{
cd “$COMBINED_REPO”

git init

}

add_remote()
{
local repo_name=”$1”
local repo_url=”$2”

git remote add "$repo_name" "$repo_url"

}

fetch_repository()
{
local repo_name=”$1”

git fetch "$repo_name" \
    '+refs/heads/*:refs/remotes/'"$repo_name"'/*'
git fetch "$repo_name" \
    '+refs/tags/*:refs/tags/*' \
    --force

}

get_default_branch()
{
local repo_name=”$1”

git remote show "$repo_name" |
    sed -n '/HEAD branch/s/.*: //p'

}

initialize_combined_branch()
{
local branch=”$1”

if [ -z "$COMBINED_BRANCH" ]; then
    COMBINED_BRANCH="$branch"
    git checkout -b "$COMBINED_BRANCH"
    git commit \
        --allow-empty \
        -m "Initial monorepo commit"
fi

}

import_repository()
{
local repo_name=”$1”
local branch=”$2”

git subtree add \
    --prefix="$repo_name" \
    "$repo_name" \
    "$branch" \
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
add_remote "$repo_name" "$repo_url"
fetch_repository "$repo_name"
default_branch=$(get_default_branch "$repo_name")
if [ -z "$default_branch" ]; then
    echo "ERROR: Unable to determine default branch for $repo_name"
    exit 1
fi
echo "Default branch: $default_branch"
initialize_combined_branch "$default_branch"
import_repository "$repo_name" "$default_branch"

}

create_remote_branch_references()
{
echo
echo “==================================================”
echo “CREATING LOCAL BRANCHES”
echo “==================================================”

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
    echo "Creating $local_branch"
    git branch -f \
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
echo "Combined branch:"
echo "  $COMBINED_BRANCH"
echo
echo "Local branches:"
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
echo "Push to mono.git:"
echo
echo "  git remote add origin <mono.git>"
echo "  git push -u origin $COMBINED_BRANCH"
echo "  git push origin --all"
echo "  git push origin --tags"

}

main()
{
[ “$#” -lt 1 ] && usage

cleanup
create_repo
for repo_url in "$@"
do
    process_repository "$repo_url"
done
create_remote_branch_references
print_summary

}

main “$@”
