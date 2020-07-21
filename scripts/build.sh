#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "\033[0;32mBuilding site...\033[0m\n"

cd website

# Build the project.
hugo # if using a theme, replace with `hugo -t <YOURTHEME>`