#!/bin/bash

set -e

###############################################################################
# Usage
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
# Create monorepo
###############################################################################

cd "$COMBINED_REPO"

git init

git commit \
    --allow-empty \
    -m "Initial monorepo commit"

###############################################################################
# Process repositories
###############################################################################

for REPO_URL in "$@"
do

    REPO_NAME=$(basename "$REPO_URL" .git)

    echo
    echo "=================================================="
    echo "PROCESSING: $REPO_NAME"
    echo "=================================================="
    echo

    ###########################################################################
    # Clone
    ###########################################################################

    cd "$WORK_DIR"

    git clone "$REPO_URL" "$REPO_NAME"

    cd "$REPO_NAME"

    ###########################################################################
    # Default branch
    ###########################################################################

    DEFAULT_BRANCH=$(
        git symbolic-ref refs/remotes/origin/HEAD \
        | sed 's@^refs/remotes/origin/@@'
    )

    echo "Default branch: $DEFAULT_BRANCH"

    git checkout "$DEFAULT_BRANCH"

    ###########################################################################
    # Find recent commits
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
    # Filter only if recent commits found
    ###########################################################################

    if [ -n "$RECENT_REFS" ]; then

        echo
        echo "Recent commits found."
        echo "Rewriting history..."
        echo

        git filter-repo \
            --force \
            --refs $RECENT_REFS

        git reflog expire \
            --expire=now \
            --all

        git gc \
            --prune=now

    else

        echo
        echo "No commits found within last $DAYS days."
        echo "Keeping full history."
        echo

    fi

    ###########################################################################
    # Import into monorepo
    ###########################################################################

    cd "$COMBINED_REPO"

    if ! git remote | grep -qx "$REPO_NAME"; then
        git remote add \
            "$REPO_NAME" \
            "$WORK_DIR/$REPO_NAME"
    fi

    git fetch "$REPO_NAME"

    echo
    echo "Remote branches:"
    git branch -r
    echo

    echo "Importing $REPO_NAME into $REPO_NAME/"
    echo

    git subtree add \
        --prefix="$REPO_NAME" \
        "$REPO_NAME" \
        "$DEFAULT_BRANCH" \
        -m "Import $REPO_NAME"

done

###############################################################################
# Done
###############################################################################

echo
echo "=================================================="
echo "DONE"
echo "=================================================="
echo

echo "Combined repository:"
echo "  $COMBINED_REPO"
echo

echo "View history:"
echo "  cd combined_repo"
echo "  git log --graph --oneline --all"
echo
