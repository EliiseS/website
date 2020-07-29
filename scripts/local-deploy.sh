#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"

# Populate modules
make sync-submodules

# Build the project.
./scripts/build.sh

# Go To Public folder
cd website/public

# Add changes to git.
git add .

# Commit changes.
msg="Updating site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin master