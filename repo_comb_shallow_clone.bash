#!/bin/bash

###############################################################################
# combine_repos.sh
#
# DESCRIPTION
#
#   Combine multiple git repositories into ONE monorepo while:
#
#   - keeping ONLY recent history
#   - preserving commit history
#   - merging repos into subdirectories
#   - using FAST shallow clone approach
#
# FINAL STRUCTURE
#
#   combined_repo/
#     ├── .git/
#     ├── A/
#     ├── B/
#     └── C/
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

###############################################################################
# Initial commit required for subtree
###############################################################################

git commit --allow-empty -m "Initial monorepo commit"

###############################################################################
# Process repositories
###############################################################################

for REPO_URL in "$@"; do

    ###########################################################################
    # Extract repository name
    ###########################################################################

    REPO_NAME=$(basename "$REPO_URL" .git)

    echo
    echo "=================================================="
    echo "PROCESSING REPOSITORY: $REPO_NAME"
    echo "=================================================="
    echo

    ###########################################################################
    # Clone only recent history
    #
    # Keeps commits newer than:
    #   N days ago
    ###########################################################################

    cd "$WORK_DIR"

    git clone \
        --shallow-since="$DAYS days ago" \
        "$REPO_URL" \
        "$REPO_NAME"

    ###########################################################################
    # Enter repository
    ###########################################################################

    cd "$REPO_NAME"

    ###########################################################################
    # Detect default branch
    ###########################################################################

    DEFAULT_BRANCH=$(
        git symbolic-ref refs/remotes/origin/HEAD \
        | sed 's@^refs/remotes/origin/@@'
    )

    echo "Default branch detected: $DEFAULT_BRANCH"

    ###########################################################################
    # Return to combined repo
    ###########################################################################

    cd "$COMBINED_REPO"

    ###########################################################################
    # Add repository as remote
    ###########################################################################

    git remote add "$REPO_NAME" "$WORK_DIR/$REPO_NAME"

    ###########################################################################
    # Fetch recent shallow history
    ###########################################################################

    git fetch "$REPO_NAME"

    ###########################################################################
    # Merge repository into subdirectory
    #
    # Example:
    #
    #   combined_repo/A/
    #   combined_repo/B/
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
echo "Only recent history from last $DAYS days was cloned."
echo
echo "View commit history:"
echo
echo "  cd combined_repo"
echo "  git log --graph --oneline --all"
echo
