build:
	printf "\033[0;32mBuilding site...\033[0m\n"
	cd website && hugo

start:
	cd website && hugo server -w

deploy:
	./scripts/deploy.sh

local-deploy:
	./scripts/local-deploy.sh

sync-submodules:
	git submodule update --init

lint: md-lint md-spell-check md-link-check

md-link-check:
	find . -type d \( -path "./node_modules" -o -path ./website/themes/AllinOne/exampleSite \)  -prune -false -o -name \*.md \
	-exec  markdown-link-check -c .markdownlinkcheck.json {} \;

md-spell-check:
	 mdspell --en-us -a -n  '**/*.md' '!**/exampleSite/**'

md-lint:
	markdownlint '**/*.md' --ignore '**/exampleSite/**'
	