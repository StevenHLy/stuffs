    ###########################################################################
    # Preserve all remote branches
    ###########################################################################

    echo
    echo "Creating local branches for $REPO_NAME ..."
    echo

    for REMOTE_BRANCH in $(
        git for-each-ref \
            --format='%(refname:short)' \
            "refs/remotes/$REPO_NAME"
    )
    do

        BRANCH_NAME=${REMOTE_BRANCH#"$REPO_NAME/"}

        if [ "$BRANCH_NAME" = "HEAD" ]; then
            continue
        fi

        LOCAL_BRANCH="${REPO_NAME}_${BRANCH_NAME}"

        echo "  $LOCAL_BRANCH"

        git branch \
            "$LOCAL_BRANCH" \
            "$REMOTE_BRANCH" \
            2>/dev/null || true

    done
