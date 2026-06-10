REPO_NAME=$(basename "$REPO_URL" .git)

echo
echo "=================================================="
echo "PROCESSING: $REPO_NAME"
echo "=================================================="
echo

###########################################################################
# Clone source repo
###########################################################################

cd "$WORK_DIR"

git clone "$REPO_URL" "$REPO_NAME"

cd "$REPO_NAME"

###########################################################################
# Fetch ALL branches and tags
###########################################################################

git fetch origin \
    '+refs/heads/*:refs/remotes/origin/*'

git fetch origin --tags

###########################################################################
# Determine default branch
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

if [ "$MODE" != "all" ] && [ "$MODE" != "0" ]; then

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
# Back to monorepo
###########################################################################

cd "$COMBINED_REPO"

###########################################################################
# Add permanent remote
###########################################################################

if ! git remote | grep -qx "$REPO_NAME"; then

    git remote add \
        "$REPO_NAME" \
        "$REPO_URL"

fi

###########################################################################
# Fetch ALL branches from source repo
###########################################################################

git fetch "$REPO_NAME" --prune

git fetch "$REPO_NAME" \
    '+refs/heads/*:refs/remotes/'"$REPO_NAME"'/*'

git fetch "$REPO_NAME" --tags

###########################################################################
# Create local branches
###########################################################################

echo
echo "Creating local branches..."
echo

git for-each-ref \
    --format='%(refname:short)' \
    "refs/remotes/$REPO_NAME" |
while read REMOTE_BRANCH
do

    BRANCH_NAME=${REMOTE_BRANCH#"$REPO_NAME/"}

    if [ "$BRANCH_NAME" = "HEAD" ]; then
        continue
    fi

    LOCAL_BRANCH="${REPO_NAME}_${BRANCH_NAME}"

    echo "  $LOCAL_BRANCH"

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

###########################################################################
# Import default branch into subtree
###########################################################################

echo
echo "Importing $REPO_NAME ..."
echo

git subtree add \
    --prefix="$REPO_NAME" \
    "$REPO_NAME" \
    "$DEFAULT_BRANCH" \
    -m "Import $REPO_NAME"
