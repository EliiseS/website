# website

![build](https://github.com/EliiseS/website/workflows/release/badge.svg)

This is the code used to generate the [eliises.github.io](https://eliises.github.io) site. The generated code can be found at [eliises/eliises.github.io](https://github.com/EliiseS/eliises.github.io).
This sites theme can be found at [eliises/AllinOne](https://github.com/EliiseS/AllinOne) and the site built using [Hugo](https://gohugo.io/).

If you've spotted a typo in that blog, you're welcome to send me a pull request here.

## Running and building locally

The easiest way to build the site locally is to open the repository in the [devcontainer](.devcontainer/Dockerfile), and then use the following command to build and start the site:

```bash
make start
```

This will then start a local web server. Changes to the content are watched, and the site will rebuild on change.

You can then open the site at <http://localhost:1313>

If you simply want to build the site then use the following command:

```bash
make build
```

This will generate the `website/public` folder.

## Deploying

Commits to this repository will kick off an Github Action pipeline. The pipeline will build the site and if the build is successful will update the `eliises/eliises.github.io` repository. Commits to `eliises/eliises.github.io` trigger Github Pages to build and deploy the website to <https://eliises.github.io>.

`eliises/eliises.github.io` repository can also be updated from the local environment using the following command:

```bash
make local-deploy
```

## Git submodules

This repository has `eliises/eliises.github.io` and `eliises/AllinOne` as git submodules. Use the following command to initialize and update the submodules:

```bash
make sync-submodules
```

## Makefile

For convenience, there is a `Makefile` in this repository that defines the following rules:

- `make build` to build the site
- `make start` to build and then serve the site on <http://localhost:1313>
- `make deploy` to deploy the site to [eliises.github.io](https://eliises.github.io) from Github Actions
- `make local-deploy` to deploy the site to [eliises.github.io](https://eliises.github.io) from the local machine
- `make sync-submodules` to initialize and update the git submodules

## Acknowledgements

This site uses a modified version of [AllinOne](https://github.com/orianna-zzo/AllinOne) for its theme, and is built using [Hugo](https://gohugo.io/). The modified version can be found at [eliises/AllinOne](https://github.com/EliiseS/AllinOne).

## License

Open sourced under the [MIT license](LICENSE).

Copyright (c) 2020 Eliise Seling
