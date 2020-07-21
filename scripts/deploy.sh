#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"

cd website/public
filesChanged=$(git status --porcelain=v1 2>/dev/null | wc -l)
if [ $filesChanged -eq 0 ]; then
	exit 0
fi

# Add git config
git config user.email "actions@github.com"
git config user.name "Github Actions"

# Add changes to git.
git add .

# Commit changes.
msg="Updating site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Push source and build repos.
git remote set-url origin git@github.com:EliiseS/eliises.github.io.git
git push origin master