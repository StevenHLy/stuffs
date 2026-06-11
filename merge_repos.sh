#!/usr/bin/env bash
# ------------------------------------------------------------
# Function: merge_repos_to_ssr
#   Merge an arbitrary number of Git repositories into one
#   "SSR" repository, preserving every branch, tag and the full
#   commit history.
#
#   After sourcing this file you can run:
#       merge_repos_to_ssr <repo1> [repo2 … repoN]
#
#   <repoX> may be a remote URL (https/ssh) or a local path.
# ------------------------------------------------------------
merge_repos_to_ssr() {
    set -euo pipefail
    IFS=$'\n\t'

    # -----------------------------------------------------------------
    # Helper: print usage and return
    # -----------------------------------------------------------------
    _usage() {
        echo "Usage: merge_repos_to_ssr <repo1> [repo2 ... repoN]"
        echo "  Each <repoX> can be a Git URL (https/ssh) or a local path."
    }

    # -----------------------------------------------------------------
    # Validate arguments
    # -----------------------------------------------------------------
    if (( $# == 0 )); then
        _usage
        return 1
    fi

    # -----------------------------------------------------------------
    # Destination directory
    # -----------------------------------------------------------------
    local dest_dir="SSR"

    if [[ -e "$dest_dir" ]]; then
        echo "Error: Destination directory '$dest_dir' already exists." >&2
        return 1
    fi

    mkdir -p "$dest_dir"
    cd "$dest_dir"
    git init -q

    # -----------------------------------------------------------------
    # Process each source repository
    # -----------------------------------------------------------------
    local remote_idx=1
    for src in "$@"; do
        local remote_name="repo${remote_idx}"
        echo "------------------------------------------------------------"
        echo "Adding remote #$remote_idx -> $src"
        git remote add "$remote_name" "$src"

        # Fetch everything (branches + tags)
        git fetch "$remote_name" --tags --prune --quiet

        # ---------- 1) Branches ----------
        # List remote branches (skip the synthetic HEAD)
        local remote_branches
        remote_branches=$(git for-each-ref --format='%(refname:short)' \
                         "refs/remotes/${remote_name}" | grep -v '^HEAD$' || true)

        for full_ref in $remote_branches; do
            # Strip remote prefix
            local branch="${full_ref#${remote_name}/}"

            # Detect name clash with an existing local branch
            if git show-ref --verify --quiet "refs/heads/${branch}"; then
                local orig_branch="${branch}"
                branch="${remote_name}_${branch}"
                echo "  → Branch clash: '${orig_branch}' → renamed to '${branch}'"
            fi

            # Create (or move) the local branch to the fetched commit
            git branch "$branch" "${remote_name}/${orig_branch:-$branch}"
        done

        # ---------- 2) Tags ----------
        # All fetched tags are already in refs/tags/*
        local tag
        for tag in $(git tag -l); do
            # If the tag exists already, namespace it
            if git rev-parse "refs/tags/${tag}" >/dev/null 2>&1; then
                if git rev-parse "refs/tags/${remote_name}_${tag}" >/dev/null 2>&1; then
                    # Double collision – extremely unlikely, skip
                    continue
                fi
                local new_tag="${remote_name}_${tag}"
                echo "  → Tag clash: '${tag}' → renamed to '${new_tag}'"
            else
                local new_tag="${tag}"
            fi
            git tag "$new_tag" "refs/tags/${tag}"
        done

        ((remote_idx++))
    done

    # -----------------------------------------------------------------
    # Set a sensible default HEAD (first remote’s default branch if possible)
    # -----------------------------------------------------------------
    if git rev-parse --verify "repo1/HEAD" >/dev/null 2>&1; then
        local default_branch
        default_branch=$(git symbolic-ref -q "refs/remotes/repo1/HEAD" \
                         | sed 's@^refs/remotes/repo1/@@')
        git checkout -q "$default_branch"
    else
        # Fallback: checkout any branch
        local any_branch
        any_branch=$(git branch --list | head -n1 | tr -d '* ')
        git checkout -q "$any_branch"
    fi

    # -----------------------------------------------------------------
    # Completion message
    # -----------------------------------------------------------------
    cat <<EOF

✅  All repositories merged into $(pwd)

Useful commands:
  git branch -a                # list every branch (local + remote)
  git tag                      # list every tag
  git log --oneline --graph --all   # view the combined history
EOF
}
