#!/bin/bash

###############################################################################
# combine_repos.sh
#
# DESCRIPTION
#
#   Combine multiple git repositories into ONE monorepo while:
#
#   - keeping ONLY recent history
#   - NOT using filter-branch
#   - NOT using filter-repo
#   - using fast shallow clones
#   - preserving recent commit history
#   - allowing future subtree pulls
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
# Create helper update script
#
# This script will later:
#
#   1. fetch latest commits from all repos
#   2. pull newest commits into subtree folders
#
###############################################################################

UPDATE_SCRIPT="$COMBINED_REPO/update_all.sh"

echo "#!/bin/bash" > "$UPDATE_SCRIPT"
echo "" >> "$UPDATE_SCRIPT"
echo "set -e" >> "$UPDATE_SCRIPT"
echo "" >> "$UPDATE_SCRIPT"

###############################################################################
# Fetch latest commit info from all remotes
###############################################################################

echo "git fetch --all" >> "$UPDATE_SCRIPT"
echo "" >> "$UPDATE_SCRIPT"

###############################################################################
# Process repositories
###############################################################################

for REPO_URL in "$@"; do

    ###########################################################################
    # Extract repo name from URL
    #
    # Example:
    #
    #   git@github.com:user/A.git
    #
    # becomes:
    #
    #   A
    ###########################################################################

    REPO_NAME=$(basename "$REPO_URL" .git)

    echo
    echo "=================================================="
    echo "PROCESSING REPOSITORY: $REPO_NAME"
    echo "=================================================="
    echo

    ###########################################################################
    # Clone ONLY recent history
    #
    # Example:
    #
    #   --shallow-since="1 day ago"
    #
    # keeps only recent commits
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
    #
    # Usually:
    #
    #   main
    #   master
    ###########################################################################

    DEFAULT_BRANCH=$(
        git symbolic-ref refs/remotes/origin/HEAD \
        | sed 's@^refs/remotes/origin/@@'
    )

    echo "Default branch: $DEFAULT_BRANCH"

    ###########################################################################
    # Return to combined repo
    ###########################################################################

    cd "$COMBINED_REPO"

    ###########################################################################
    # Add ORIGINAL repository URL as remote
    #
    # Example:
    #
    #   remote name:
    #       A
    #
    #   remote url:
    #       git@github.com:user/A.git
    #
    # This allows future updates later.
    ###########################################################################

    git remote add "$REPO_NAME" "$REPO_URL"

    ###########################################################################
    # Fetch recent history
    ###########################################################################

    git fetch "$REPO_NAME"

    ###########################################################################
    # Merge repository into subdirectory
    #
    # Example:
    #
    #   combined_repo/A/
    ###########################################################################

    echo
    echo "Merging into:"
    echo "  $REPO_NAME/"
    echo

    git subtree add \
        --prefix="$REPO_NAME" \
        "$REPO_NAME" \
        "$DEFAULT_BRANCH"

    ###########################################################################
    # Add subtree update command to helper script
    #
    # Example generated command:
    #
    #   git subtree pull --prefix=A A main
    #
    # Meaning:
    #
    #   --prefix=A
    #       update folder:
    #           combined_repo/A/
    #
    #   A
    #       remote name
    #
    #   main
    #       remote branch
    #
    ###########################################################################

    echo "git subtree pull --prefix=$REPO_NAME $REPO_NAME $DEFAULT_BRANCH" \
        >> "$UPDATE_SCRIPT"

    echo "" >> "$UPDATE_SCRIPT"

done

###############################################################################
# Make helper update script executable
###############################################################################

chmod +x "$UPDATE_SCRIPT"

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
echo "--------------------------------------------------"
echo "HOW TO VIEW HISTORY"
echo "--------------------------------------------------"
echo
echo "cd combined_repo"
echo
echo "git log --graph --oneline --all"
echo
echo "--------------------------------------------------"
echo "HOW TO CHECK FOR NEW COMMITS"
echo "--------------------------------------------------"
echo
echo "cd combined_repo"
echo
echo "git fetch --all"
echo
echo "git log HEAD..A/main --oneline"
echo
echo "If output appears:"
echo "  repo A has new commits"
echo
echo "--------------------------------------------------"
echo "HOW TO PULL LATEST COMMITS"
echo "--------------------------------------------------"
echo
echo "cd combined_repo"
echo
echo "./update_all.sh"
echo
echo "This pulls newest commits from:"
echo "  A"
echo "  B"
echo "  C"
echo
