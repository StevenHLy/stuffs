#!/bin/bash

###############################################################################
#
# combine_repos.sh
#
# Modes:
#
#   Full history:
#
#       ./combine_repos.sh all <repo1> <repo2> ...
#
#   Keep commits within N days:
#
#       ./combine_repos.sh 1 <repo1> <repo2> ...
#       ./combine_repos.sh 7 <repo1> <repo2> ...
#       ./combine_repos.sh 30 <repo1> <repo2> ...
#
# Behavior:
#
#   If commits exist within N days:
#       - rewrite history using git-filter-repo
#       - import rewritten history
#
#   If no commits exist within N days:
#       - keep full history
#       - import full history
#
# Requirements:
#
#   git
#   git subtree
#   git-filter-repo
#
###############################################################################

set -e

###############################################################################
# Validate arguments
###############################################################################

if [ "$#" -lt 2 ]; then
    echo
    echo "Usage:"
    echo "  $0 <all|days> <repo1> [repo2] ..."
    echo
    echo "Examples:"
    echo
    echo "  $0 all git@github.com:user/A.git git@github.com:user/B.git"
    echo
    echo "  $0 7 git@github.com:user/A.git git@github.com:user/B.git"
    echo
    exit 1
fi

###############################################################################
# Parse arguments
###############################################################################

MODE="$1"
shift

###############################################################################
# Directories
###############################################################################

ROOT_DIR="$(pwd)"
WORK_DIR="$ROOT_DIR/.repo_work"
COMBINED_REPO="$ROOT_DIR/combined_repo"

###############################################################################
# Cleanup previous run
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
    # Optional history filtering
    ###########################################################################

    if [ "$MODE" = "all" ] || [ "$MODE" = "0" ]; then

        echo
        echo "Keeping full history."
        echo

    else

        echo
        echo "Finding commits newer than $MODE day(s)..."
        echo

        RECENT_REFS=$(
            git rev-list \
                --since="$MODE days ago" \
                --all
        )

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
            echo "No commits found within last $MODE day(s)."
            echo "Keeping full history."
            echo

        fi

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
    echo "Importing $REPO_NAME into $REPO_NAME/"
    echo

    git subtree add \
        --prefix="$REPO_NAME" \
        "$REPO_NAME" \
        "$DEFAULT_BRANCH" \
        -m "Import $REPO_NAME"

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
echo "  $COMBINED_REPO"
echo

echo "View history:"
echo "  cd combined_repo"
echo "  git log --graph --oneline --all"
echo
