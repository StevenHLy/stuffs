if [ -z "$RECENT_REFS" ]; then

    echo "No commits in last $DAYS days."
    echo "Using full history."

else

    git filter-repo \
        --force \
        --refs $RECENT_REFS

fi
#######
if [ -z "$RECENT_REFS" ]; then
    echo "Skipping filter-repo, keeping full history."
else
    git filter-repo \
        --force \
        --refs $RECENT_REFS
fi
