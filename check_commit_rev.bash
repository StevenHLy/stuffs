echo
echo "Checking $REPO..."

git fetch "$REPO"

COUNT=$(git rev-list --count HEAD.."$REPO/$BRANCH")

if [ "$COUNT" -gt 0 ]; then

    echo "Found $COUNT new commit(s) in $REPO"

    git subtree pull \
        --prefix="$REPO" \
        "$REPO" \
        "$BRANCH" \
        -m "Sync $REPO"

else

    echo "$REPO is already up to date"

fi
