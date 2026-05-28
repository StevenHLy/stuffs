#!/bin/bash
###############################################################################
# combine_repos.sh
#
# Combine multiple git repositories into one monorepo while:
#
#   - keeping ONLY commits from last N days
#   - rewriting history using git-filter-repo
#   - preserving rewritten commit history
#   - merging repos into subdirectories
#
# REQUIREMENTS:
#
#   git
#   git subtree
#   git-filter-repo
#
# INSTALL:
#
#   pip install git-filter-repo
#
# USAGE:
#
#   chmod +x combine_repos.sh
#
#   ./combine_repos.sh <days> <repo1> <repo2> ...
#
# EXAMPLE:
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
# Cleanup old runs
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
    # Get recent commits
    ###########################################################################
    echo
    echo "Finding commits newer than $DAYS days..."
    echo
    RECENT_REFS=$(
        git rev-list \
            --since="$DAYS days ago" \
            --all
    )
    ###########################################################################
    # Skip if no commits found
    ###########################################################################
    if [ -z "$RECENT_REFS" ]; then
        echo
        echo "No commits found within last $DAYS days."
        echo "Skipping repository."
        echo
        continue
    fi
    ###########################################################################
    # Rewrite history using git-filter-repo
    ###########################################################################
    echo
    echo "Rewriting history..."
    echo
    git filter-repo \
        --force \
        --refs $RECENT_REFS
    ###########################################################################
    # Cleanup unreachable objects
    ###########################################################################
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
    echo "Merging into subdirectory:"
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
echo "View merged history:"
echo
echo "  cd combined_repo"
echo "  git log --graph --oneline --all"
echo