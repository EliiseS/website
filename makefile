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