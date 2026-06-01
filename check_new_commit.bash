#!/bin/bash

set -e

###############################################################################

Update repository A

###############################################################################

echo
echo “Checking A…”

git fetch A

if [ -n “$(git log HEAD..A/main –oneline 2>/dev/null)” ]; then

echo "New commits found in A"
git subtree pull \
    --prefix=A \
    A \
    main \
    -m "Sync A"

else

echo "No updates in A"

fi

###############################################################################

Update repository B

###############################################################################

echo
echo “Checking B…”

git fetch B

if [ -n “$(git log HEAD..B/main –oneline 2>/dev/null)” ]; then

echo "New commits found in B"
git subtree pull \
    --prefix=B \
    B \
    main \
    -m "Sync B"

else

echo "No updates in B"

fi

###############################################################################

Update repository C

###############################################################################

echo
echo “Checking C…”

git fetch C

if [ -n “$(git log HEAD..C/main –oneline 2>/dev/null)” ]; then

echo "New commits found in C"
git subtree pull \
    --prefix=C \
    C \
    main \
    -m "Sync C"

else

echo "No updates in C"

fi

###############################################################################

Done

###############################################################################

echo
echo “All repositories checked.”
echo
