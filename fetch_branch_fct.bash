#!/bin/bash
set -e
###############################################################################
# Functions
###############################################################################
log_header()
{
    echo
    echo "=================================================="
    echo "$1"
    echo "=================================================="
    echo
}
validate_args()
{
    if [ "$#" -lt 2 ]; then
        echo
        echo "Usage:"
        echo "  $0 <all|days> <repo1> [repo2] ..."
        echo
        exit 1
    fi
}
init_workspace()
{
    rm -rf "$WORK_DIR"
    rm -rf "$COMBINED_REPO"
    mkdir -p "$WORK_DIR"
    mkdir -p "$COMBINED_REPO"
    cd "$COMBINED_REPO"
    git init
    git commit \
        --allow-empty \
        -m "Initial monorepo commit"
}
get_default_branch()
{
    git symbolic-ref refs/remotes/origin/HEAD \
        | sed 's@^refs/remotes/origin/@@'
}
filter_history()
{
    local MODE="$1"
    if [ "$MODE" = "all" ] || [ "$MODE" = "0" ]; then
        echo "Keeping full history."
        return
    fi
    RECENT_REFS=$(
        git rev-list \
            --since="$MODE days ago" \
            --all
    )
    if [ -n "$RECENT_REFS" ]; then
        git filter-repo \
            --force \
            --refs $RECENT_REFS
        git reflog expire \
            --expire=now \
            --all
        git gc \
            --prune=now
    else
        echo "No recent commits found."
        echo "Keeping full history."
    fi
}
add_source_remote()
{
    local REPO_NAME="$1"
    local REPO_URL="$2"
    if ! git remote | grep -qx "$REPO_NAME"; then
        git remote add \
            "$REPO_NAME" \
            "$REPO_URL"
    fi
    git fetch "$REPO_NAME" --prune
    git fetch "$REPO_NAME" \
        '+refs/heads/*:refs/remotes/'"$REPO_NAME"'/*'
    git fetch "$REPO_NAME" --tags
}
create_tracking_branches()
{
    local REPO_NAME="$1"
    git for-each-ref \
        --format='%(refname:short)' \
        "refs/remotes/$REPO_NAME" |
    while read REMOTE_BRANCH
    do
        BRANCH_NAME=${REMOTE_BRANCH#"$REPO_NAME/"}
        [ "$BRANCH_NAME" = "HEAD" ] && continue
        LOCAL_BRANCH="${REPO_NAME}_${BRANCH_NAME}"
        if ! git show-ref \
            --verify \
            --quiet \
            "refs/heads/$LOCAL_BRANCH"
        then
            git branch \
                "$LOCAL_BRANCH" \
                "$REMOTE_BRANCH"
        fi
    done
}
import_subtree()
{
    local REPO_NAME="$1"
    local DEFAULT_BRANCH="$2"
    git subtree add \
        --prefix="$REPO_NAME" \
        "$REPO_NAME" \
        "$DEFAULT_BRANCH" \
        -m "Import $REPO_NAME"
}
###############################################################################
# Main
###############################################################################
validate_args "$@"
MODE="$1"
shift
ROOT_DIR="$(pwd)"
WORK_DIR="$ROOT_DIR/.repo_work"
COMBINED_REPO="$ROOT_DIR/combined_repo"
init_workspace
for REPO_URL in "$@"
do
    REPO_NAME=$(basename "$REPO_URL" .git)
    log_header "PROCESSING: $REPO_NAME"
    cd "$WORK_DIR"
    git clone "$REPO_URL" "$REPO_NAME"
    cd "$REPO_NAME"
    git fetch origin '+refs/heads/*:refs/remotes/origin/*'
    git fetch origin --tags
    DEFAULT_BRANCH=$(get_default_branch)
    git checkout "$DEFAULT_BRANCH"
    filter_history "$MODE"
    cd "$COMBINED_REPO"
    add_source_remote \
        "$REPO_NAME" \
        "$REPO_URL"
    create_tracking_branches \
        "$REPO_NAME"
    import_subtree \
        "$REPO_NAME" \
        "$DEFAULT_BRANCH"
done
log_header "DONE"
git branch
