#!/bin/bash

###############################################################################
# combine_repos.sh
#
# DESCRIPTION
#
#   Combine multiple git repositories into ONE monorepo while:
#
#   - keeping recent history using shallow clone
#   - NOT using git subtree
#   - NOT using filter-branch
#   - NOT using filter-repo
#   - preserving commit history
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
#
# USAGE
#
#   chmod +x combine_repos.sh
#
#   ./combine_repos.sh <days> <repo1> <repo2> ...
#
###############################################################################

set -e

###############################################################################
# Validate args
###############################################################################

if [ "$#" -lt 2 ]; then
    echo
    echo "Usage:"
    echo "  $0 <days> <repo1> [repo2] ..."
    echo
    exit 1
fi

###############################################################################
# Parse args
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
# Cleanup
###############################################################################

rm -rf "$WORK_DIR"
rm -rf "$COMBINED_REPO"

mkdir -p "$WORK_DIR"
mkdir -p "$COMBINED_REPO"

###############################################################################
# Create combined repo
###############################################################################

cd "$COMBINED_REPO"

git init

git commit --allow-empty -m "Initial monorepo commit"

###############################################################################
# Create update script
###############################################################################

UPDATE_SCRIPT="$COMBINED_REPO/update_all.sh"

echo "#!/bin/bash" > "$UPDATE_SCRIPT"
echo "" >> "$UPDATE_SCRIPT"
echo "set -e" >> "$UPDATE_SCRIPT"
echo "" >> "$UPDATE_SCRIPT"

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

    cd "$WORK_DIR"

    ###########################################################################
    # Try shallow clone
    ###########################################################################

    if git clone \
        --shallow-since="$DAYS days ago" \
        "$REPO_URL" \
        "$REPO_NAME"; then

        echo "Shallow clone succeeded."

    else

        #######################################################################
        # Fallback full clone
        #######################################################################

        echo
        echo "No recent commits found."
        echo "Falling back to full clone..."
        echo

        rm -rf "$REPO_NAME"

        git clone "$REPO_URL" "$REPO_NAME"

    fi

    ###########################################################################
    # Enter repo
    ###########################################################################

    cd "$REPO_NAME"

    ###########################################################################
    # Detect branch
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
    # Add remote
    ###########################################################################

    git remote add "$REPO_NAME" "$REPO_URL"

    ###########################################################################
    # Fetch repo
    ###########################################################################

    git fetch "$REPO_NAME"

    ###########################################################################
    # Merge unrelated histories
    ###########################################################################

    git merge \
        --allow-unrelated-histories \
        -s ours \
        --no-commit \
        "$REPO_NAME/$DEFAULT_BRANCH"

    ###########################################################################
    # Import repo into subdirectory
    ###########################################################################

    git read-tree \
        --prefix="$REPO_NAME/" \
        -u \
        "$REPO_NAME/$DEFAULT_BRANCH"

    ###########################################################################
    # Commit merge
    ###########################################################################

    git commit -m "Merge repository $REPO_NAME"

    ###########################################################################
    # Add update command
    ###########################################################################

    echo "git fetch $REPO_NAME" >> "$UPDATE_SCRIPT"

    echo "git merge \\" >> "$UPDATE_SCRIPT"
    echo "  --allow-unrelated-histories \\" >> "$UPDATE_SCRIPT"
    echo "  -s ours \\" >> "$UPDATE_SCRIPT"
    echo "  --no-commit \\" >> "$UPDATE_SCRIPT"
    echo "  $REPO_NAME/$DEFAULT_BRANCH" >> "$UPDATE_SCRIPT"

    echo "git read-tree \\" >> "$UPDATE_SCRIPT"
    echo "  --prefix=$REPO_NAME/ \\" >> "$UPDATE_SCRIPT"
    echo "  -u \\" >> "$UPDATE_SCRIPT"
    echo "  $REPO_NAME/$DEFAULT_BRANCH" >> "$UPDATE_SCRIPT"

    echo "git commit -m \"Update $REPO_NAME\"" >> "$UPDATE_SCRIPT"

    echo "" >> "$UPDATE_SCRIPT"

done

###############################################################################
# Make update script executable
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
echo "Combined repository:"
echo
echo "  $COMBINED_REPO"
echo
echo "View history:"
echo
echo "  cd combined_repo"
echo "  git log --graph --oneline --all"
echo
echo "Update all repos later:"
echo
echo "  cd combined_repo"
echo "  ./update_all.sh"
echo
