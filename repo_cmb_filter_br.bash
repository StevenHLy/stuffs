#!/bin/bash
###############################################################################
# combine_repos.sh
#
# DESCRIPTION
#
#   Combine multiple git repositories into ONE monorepo while:
#
#   - keeping ONLY commits from last N days
#   - rewriting history using git filter-branch
#   - preserving rewritten history
#   - merging repos into subdirectories
#
# REQUIREMENTS
#
#   git
#   git subtree
#
# USAGE
#
#   chmod +x combine_repos.sh
#
#   ./combine_repos.sh <days> <repo1> <repo2> ...
#
# EXAMPLE
#
#   ./combine_repos.sh 1 \
#       git@github.com:user/A.git \
#       git@github.com:user/B.git \
#       git@github.com:user/C.git
#
###############################################################################
set -e
###############################################################################
# Validate arguments
###############################################################################
if [ "$#" -lt 2 ]; then
    echo
    echo "Usage:"
    echo "  $0 <days> <repo1> [repo2] ..."
    echo
    exit 1
fi
###############################################################################
# Parse arguments
###############################################################################
DAYS="$1"
shift
###############################################################################
# Directories
###############################################################################
ROOT_DIR="$(pwd)"
WORK_DIR="$ROOT_DIR/.repo_work"
COMBINED_REPO="$ROOT_DIR/combined_repo"
###############################################################################
# Cleanup previous runs
###############################################################################
rm -rf "$WORK_DIR"
rm -rf "$COMBINED_REPO"
mkdir -p "$WORK_DIR"
mkdir -p "$COMBINED_REPO"
###############################################################################
# Create combined monorepo
###############################################################################
cd "$COMBINED_REPO"
git init
git commit --allow-empty -m "Initial monorepo commit"
###############################################################################
# Process repositories
###############################################################################
for REPO_URL in "$@"; do
    ###########################################################################
    # Repo name
    ###########################################################################
    REPO_NAME=$(basename "$REPO_URL" .git)
    echo
    echo "=================================================="
    echo "PROCESSING: $REPO_NAME"
    echo "=================================================="
    echo
    ###########################################################################
    # Clone repository
    ###########################################################################
    cd "$WORK_DIR"
    git clone "$REPO_URL" "$REPO_NAME"
    cd "$REPO_NAME"
    ###########################################################################
    # Detect default branch
    ###########################################################################
    DEFAULT_BRANCH=$(
        git symbolic-ref refs/remotes/origin/HEAD \
        | sed 's@^refs/remotes/origin/@@'
    )
    echo "Default branch: $DEFAULT_BRANCH"
    git checkout "$DEFAULT_BRANCH"
    ###########################################################################
    # Rewrite history
    #
    # Keep ONLY commits newer than N days
    ###########################################################################
    echo
    echo "Rewriting history using git filter-branch..."
    echo
    git filter-branch \
        --prune-empty \
        --tag-name-filter cat \
        -- --all --since="$DAYS days ago"
    ###########################################################################
    # Cleanup old references
    ###########################################################################
    rm -rf .git/refs/original/
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive
    ###########################################################################
    # Add rewritten repo into combined repo
    ###########################################################################
    cd "$COMBINED_REPO"
    ###########################################################################
    # Add remote
    ###########################################################################
    git remote add "$REPO_NAME" "$WORK_DIR/$REPO_NAME"
    ###########################################################################
    # Fetch rewritten history
    ###########################################################################
    git fetch "$REPO_NAME"
    ###########################################################################
    # Merge repository into subdirectory
    ###########################################################################
    echo
    echo "Merging repository into:"
    echo "  $REPO_NAME/"
    echo
    git subtree add \
        --prefix="$REPO_NAME" \
        "$REPO_NAME" \
        "$DEFAULT_BRANCH"
done
###############################################################################
# Finished
###############################################################################
echo
echo "=================================================="
echo "DONE"
echo "=================================================="
echo
echo "Combined repository created:"
echo
echo "  $COMBINED_REPO"
echo
echo "View history:"
echo
echo "  cd combined_repo"
echo "  git log --graph --oneline --all"
echo
