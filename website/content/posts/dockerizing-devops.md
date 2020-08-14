---
title: "Dockerizing DevOps"
date: 2020-07-08T17:00:13Z
series: ["devcontainer"]
img: "images/dockerizing-devops/devops-loop.svg"
toc: true
categories: ["devops, vscode"]
summary: "Reusing a devcontainer build environment for pipelines"
---

In this post I'd like to present how to reuse a [devcontainer](https://code.visualstudio.com/docs/remote/containers) as the build environment for pipelines. A devcontainer is a Docker container used as full-featured development environment. To learn more about what makes devcontainers awesome, see [Visual Studio Code and Devcontainers article](https://stuartleeks.com/posts/vscode-devcontainers/) by my dear friend, Stuart Leeks.

A typical CI pipeline consists of `source -> build -> test` stages. Both build and test stages have dependencies (on software and configuration) that need to be configured within the pipeline itself. Since these dependencies are already setup in your `devcontainer`, why not just use that environment to run your build and tests in?

While the examples below use [AzDO YAML pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=schema%2Cparameter-schema), this can be achieved with any CI environment. Lawrence Gripper's [AzBrowze](https://github.com/lawrencegripper/azbrowse) is an example of a repository using devcontainer pipelines with [Github Actions](https://github.com/features/actions).

All code snippets can be found in [terraform-pester-devcontainer-example repository](https://github.com/EliiseS/terraform-pester-devcontainer-example).

## Requirements

- Intermediate knowledge of [Docker](https://docs.docker.com/), [devcontainers](https://code.visualstudio.com/docs/remote/containers) and CI/CD pipelines
- Basic knowledge of [AzDO YAML pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=schema%2Cparameter-schema) and [Makefiles](https://opensource.com/article/18/8/what-how-makefile) is helpful

## About the project

I've created the [terraform-pester-devcontainer-example repository](https://github.com/EliiseS/terraform-pester-devcontainer-example) to demonstrate devcontainer pipelines. The project consists of:
- [terraform](https://github.com/EliiseS/terraform-pester-devcontainer-example/blob/master/main.tf) to provision resources in Azure Devops
- [tests](https://github.com/EliiseS/terraform-pester-devcontainer-example/blob/master/tfIntegration.tests.ps1) covering the terraform written in Pester, a powershell testing framework
   - More about testing terraform with Pester [in my previous post](https://dev.to/eliises/testing-terraform-with-pester-1b01)
- [devcontainer](https://github.com/EliiseS/terraform-pester-devcontainer-example/blob/master/.devcontainer/Dockerfile) with the development environment

### CI pipeline checks

In a CI pipeline for this project we want to:
- validate terraform with tflint
- run the Pester tests
- validate the devcontainer can be built

## Classic pipeline

In a classic or standard pipeline, we first install the dependencies in the pipeline and then run our checks:

##### [.azdo/classic-pipeline.yml](https://github.com/EliiseS/terraform-pester-devcontainer-example/blob/master/.azdo/classic-pipeline.yml)
```yml
 steps:
      # Install dependencies
      - task: TerraformInstaller@0
        displayName: 'Install terraform'
        inputs:
          terraformVersion: 0.12.25

      - task: Bash@3
        displayName: Install tflint
        inputs:
          targetType: 'inline'
          script: |
            curl -L https://github.com/terraform-linters/tflint/releases/download/v0.17.0/tflint_linux_amd64.zip -o tflint.zip
            unzip tflint.zip
            rm tflint.zip
            sudo mv tflint /usr/local/bin \

      - task: PowerShell@2
        displayName: Install Pester module
        inputs:
          targetType: 'inline'
          script: Install-Module -Name Pester -Force -RequiredVersion 4.10.1

      # Run checks
      - task: PowerShell@2
        displayName: Validate terraform
        inputs:
          targetType: 'inline'
          script: |
            terraform init
            terraform validate
            tflint

      - task: PowerShell@2
        displayName: Run tests
        env:
          AZURE_DEVOPS_EXT_PAT: $(AZDO_PERSONAL_ACCESS_TOKEN)
          AZDO_PERSONAL_ACCESS_TOKEN: $(AZDO_PERSONAL_ACCESS_TOKEN)
          AZDO_ORG_SERVICE_URL: $(AZDO_ORG_SERVICE_URL)
        inputs:
          targetType: 'inline'
          script: Invoke-Pester -EnableExit

      - task: PowerShell@2
        displayName: Build devcontainer
        inputs:
          targetType: 'inline'
          script: docker build -f .devcontainer/Dockerfile -t devcontainer .
```

### Build times

Below we can see the time the build took. Installing dependencies locally is very fast, with majority of the time being spent on building the dev container. Looking at this, the best way to save time on your builds it by not using a devcontainer at all! Luckily, there are other benefits that more than make up for this gluttony.

![Classic pipeline](/images/dockerizing-devops/classic-pipeline.png)

## Devcontainer pipeline

Now lets do what we've all been waiting for and convert the above pipeline to now instead run the tasks inside of the devcontainer:

##### [.azdo/devcontainer-pipeline.yml](https://github.com/EliiseS/terraform-pester-devcontainer-example/blob/master/.azdo/devcontainer-pipeline.yml)
```yml
steps:
      # Build the devcontainer
      - task: PowerShell@2
        displayName: Build devcontainer
        inputs:
          targetType: 'inline'
          script: docker build -f .devcontainer/Dockerfile -t devcontainer .

      # Run checks inside the devcontainer
      - task: PowerShell@2
        displayName: Validate terraform
        inputs:
          targetType: 'inline'
          script: |
            docker run `
              --entrypoint /opt/microsoft/powershell/7/pwsh `
              -v $(System.DefaultWorkingDirectory):/src `
              --workdir /src `
              devcontainer `
              -c "terraform init && terraform validate && tflint"

      - task: PowerShell@2
        displayName: Run tests
        env:
          AZDO_PERSONAL_ACCESS_TOKEN: $(AZDO_PERSONAL_ACCESS_TOKEN)
          AZDO_ORG_SERVICE_URL: $(AZDO_ORG_SERVICE_URL)
        inputs:
          targetType: 'inline'
          script: |
            docker run `
              -e AZURE_DEVOPS_EXT_PAT=$(AZDO_PERSONAL_ACCESS_TOKEN) `
              -e AZDO_PERSONAL_ACCESS_TOKEN=$(AZDO_PERSONAL_ACCESS_TOKEN) `
              -e AZDO_ORG_SERVICE_URL=$(AZDO_ORG_SERVICE_URL) `
              --entrypoint /opt/microsoft/powershell/7/pwsh `
              -v $(System.DefaultWorkingDirectory):/src `
              --workdir /src `
              devcontainer `
              -c Invoke-Pester -EnableExit
```

### Build times

Below we can see that we've shaved off a few seconds, but nothing amazing.

![Devcontainer pipeline](/images/dockerizing-devops/devcontainer-pipeline.png)

## Devcontainer pipeline with caching

As a bonus, we can also cache our devcontainer image between runs to further reduce the time the builds take. Take a look at the YAML below:

##### [.azdo/devcontainer-caching-pipeline.yml](https://github.com/EliiseS/terraform-pester-devcontainer-example/blob/master/.azdo/devcontainer-caching-pipeline.yml)
```yml
    steps:
      # Initialize caching 
      - task: Cache@2
        inputs:
          key: docker-image | .devcontainer/**
          path: '.dockercache'
          restoreKeys: docker-image
          cacheHitVar: DOCKER_CACHE_HIT
        displayName: Cache docker layers

      # Load the cached image if cache was found
      - task: PowerShell@2
        displayName: Load cached devcontainer image
        condition: eq(variables.DOCKER_CACHE_HIT, 'true')
        inputs:
          targetType: 'inline'
          script: docker load -i ./.dockercache/devcontainer.tar

      # Build the devcontainer
      - task: PowerShell@2
        displayName: 'Build devcontainer'
        inputs:
          targetType: 'inline'
          script: |
            # Create dockercache directory
            mkdir -p ./.dockercache/
            docker build --cache-from devcontainer:latest -f .devcontainer/Dockerfile -t devcontainer .

      # Cache the docker image file if build succeeded
      - task: PowerShell@2
        displayName: Save devcontainer image
        condition: and(succeeded(), ne(variables.DOCKER_CACHE_HIT, 'true'))
        inputs:
          targetType: 'inline'
          script: docker image save -o ./.dockercache/devcontainer.tar devcontainer

      # Run checks in the devcontainer
      - task: PowerShell@2
        displayName: Validate terraform
        inputs:
          targetType: 'inline'
          script: |
            docker run `
              --entrypoint /opt/microsoft/powershell/7/pwsh `
              -v $(System.DefaultWorkingDirectory):/src `
              --workdir /src `
              devcontainer `
              -c "terraform init && terraform validate && tflint"

      - task: PowerShell@2
        displayName: Run tests
        env:
          AZDO_PERSONAL_ACCESS_TOKEN: $(AZDO_PERSONAL_ACCESS_TOKEN)
          AZDO_ORG_SERVICE_URL: $(AZDO_ORG_SERVICE_URL)
        inputs:
          targetType: 'inline'
          script: |
            docker run `
              -e AZURE_DEVOPS_EXT_PAT=$(AZDO_PERSONAL_ACCESS_TOKEN) `
              -e AZDO_PERSONAL_ACCESS_TOKEN=$(AZDO_PERSONAL_ACCESS_TOKEN) `
              -e AZDO_ORG_SERVICE_URL=$(AZDO_ORG_SERVICE_URL) `
              --entrypoint /opt/microsoft/powershell/7/pwsh `
              -v $(System.DefaultWorkingDirectory):/src `
              --workdir /src `
              devcontainer `
              -c Invoke-Pester -EnableExit
```

### Alternatives to caching

An alternatives to caching is using a container registry to save your image, such as the [azure container registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-intro) or [docker hub](https://docs.docker.com/docker-hub/). Infact [AzBrowze](https://github.com/lawrencegripper/azbrowse) is using docker hub for it's caching.

### Build times

With cashing we can see that our run times actually increased the first time the build in run:

![Caching pipeline](/images/dockerizing-devops/caching-pipeline.png)

But on consecutive runs when we are retrieving the cache, it's lower overall.

![Caching pipelines](/images/dockerizing-devops/caching-pipelines.png)

## Build time overview

All the build times side-by-side:

![All pipelines](/images/dockerizing-devops/all-pipelines.png)

## Execute commands in container locally

For troubleshooting or verifying your commands will run in your container, you can also execute them in your local machine:

```sh
## Build the devcontainer
docker build -t devcontainer -f ./.devcontainer/Dockerfile .
## Execute commands in the container
docker run `
        -e AZURE_DEVOPS_EXT_PAT=$env:AZDO_PERSONAL_ACCESS_TOKEN `
        -e AZDO_PERSONAL_ACCESS_TOKEN=$env:AZDO_PERSONAL_ACCESS_TOKEN `
        -e AZDO_ORG_SERVICE_URL=$env:AZDO_ORG_SERVICE_URL `
        --entrypoint /opt/microsoft/powershell/7/pwsh `
        # Replace `<host/source/directory>` with the local path to the repo
        -v <host/source/directory>:/src `
        --workdir /src `
        devcontainer `
        # Replace `Invoke-Pester` with your desired command
        -c Invoke-Pester
```

## Pros and cons

### Cons

- Building a docker image is slower than just installing dependencies
  - This con is negated if you're already using and build a devcontainer
- An alternative to running your build pipeline in a devcontainer is extracting dependency installation into a script and using that script in the pipeline and devcontainer.

### Pros

- Consistent, traceable and fully automated creation of the environment (container) by a docker file
- Standardized environment to use for all developers
- Easy distribution of the container and its updates for all developers
- Reduces the effort to maintain the environment in the pipeline through scripts or similar
- Having an identical environment for the developers and the pipeline lowers the probability of errors resulting from inconsistent environments (e.g. different Go compiler version)

## Epilogue

While I'm clearly biased towards devcontainers I'd love hear what everyone else thinks on the matter. And do let me know if I've missed anything or if something is broken!

