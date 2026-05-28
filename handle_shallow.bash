#!/bin/bash

###############################################################################
# combine_repos.sh
#
# DESCRIPTION
#
#   Combine multiple git repositories into ONE monorepo while:
#
#   - trying shallow clone first
#   - falling back to full clone if no recent commits exist
#   - preserving commit history
#   - merging repos into subdirectories
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
# Create update helper script
###############################################################################

UPDATE_SCRIPT="$COMBINED_REPO/update_all.sh"

echo "#!/bin/bash" > "$UPDATE_SCRIPT"
echo "" >> "$UPDATE_SCRIPT"
echo "set -e" >> "$UPDATE_SCRIPT"
echo "" >> "$UPDATE_SCRIPT"
echo "git fetch --all" >> "$UPDATE_SCRIPT"
echo "" >> "$UPDATE_SCRIPT"

###############################################################################
# Process repositories
###############################################################################

for REPO_URL in "$@"; do

    ###########################################################################
    # Extract repo name
    ###########################################################################

    REPO_NAME=$(basename "$REPO_URL" .git)

    echo
    echo "=================================================="
    echo "PROCESSING REPOSITORY: $REPO_NAME"
    echo "=================================================="
    echo

    cd "$WORK_DIR"

    ###########################################################################
    # Try shallow clone first
    #
    # Keeps only recent history
    ###########################################################################

    echo "Trying shallow clone..."

    if git clone \
        --shallow-since="$DAYS days ago" \
        "$REPO_URL" \
        "$REPO_NAME"; then

        echo "Shallow clone succeeded."

    else

        #######################################################################
        # No recent commits found
        #
        # Fallback to full clone
        #######################################################################

        echo
        echo "No commits found within last $DAYS days."
        echo "Falling back to full clone..."
        echo

        rm -rf "$REPO_NAME"

        git clone "$REPO_URL" "$REPO_NAME"

    fi

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

    echo "Default branch: $DEFAULT_BRANCH"

    ###########################################################################
    # Return to combined repo
    ###########################################################################

    cd "$COMBINED_REPO"

    ###########################################################################
    # Add original repo URL as remote
    #
    # Example:
    #
    #   remote name:
    #       A
    #
    #   remote url:
    #       git@github.com:user/A.git
    ###########################################################################

    git remote add "$REPO_NAME" "$REPO_URL"

    ###########################################################################
    # Fetch repository
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
    echo "Merging repository into:"
    echo "  $REPO_NAME/"
    echo

    git subtree add \
        --prefix="$REPO_NAME" \
        "$REPO_NAME" \
        "$DEFAULT_BRANCH"

    ###########################################################################
    # Add future update command
    ###########################################################################

    echo "git subtree pull --prefix=$REPO_NAME $REPO_NAME $DEFAULT_BRANCH" \
        >> "$UPDATE_SCRIPT"

    echo "" >> "$UPDATE_SCRIPT"

done

###############################################################################
# Make update helper executable
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
echo "This updates repos:"
echo "  A"
echo "  B"
echo "  C"
echo
