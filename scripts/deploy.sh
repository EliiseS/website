#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "\033[0;32m Deploying updates to GitHub...\033[0m\n"

cd website/public
filesChanged=$(git status --porcelain=v1 2>/dev/null | wc -l)
if [ $filesChanged -eq 0 ]; then
	exit 0
fi

# Add git config
git config user.email "actions@github.com"
git config user.name "Github Actions"

# Add changes to git.
printf "\033[0;32m Add changes to git...\033[0m\n"
git add .

# Commit changes.
printf "\033[0;32m Commiting changes...\033[0m\n"
msg="Updating site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Push source and build repos.
printf "\033[0;32m Push site submodule...\033[0m\n"
git push "https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/EliiseS/eliises.github.io.git" HEAD:master

printf "\033[0;32m Add submodule changes to this repo...\033[0m\n"
cd -
# Add git config
git config user.email "actions@github.com"
git config user.name "Github Actions"
git add .
git commit -m "$msg"
git push "https://${GITHUB_ACTOR}:${INPUT_GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:master