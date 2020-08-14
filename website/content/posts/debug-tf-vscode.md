---
title: "Debug Terraform (Azure Devops) Provider with VSCode"
date: 2020-07-01T16:30:46Z
lastmod: 2020-07-20T09:43:36Z
toc: true
categories: ["terraform, testing, go, vscode"]
noSummary: true
---

# Introduction

In an effort to save someone the pain of having to go through what I did when trying to get debugging to work on the [Terraform Azure Devops Provider](https://github.com/terraform-providers/terraform-provider-azuredevops) acceptance tests, here's the solution.

Prior to starting I was already able to run, debug the unit tests and run the acceptance tests. This article is only about enabling debugging for terraform acceptance tests.

**Update**: Checkout the [Issues section](#issues) for how to enable codelens debugging.

# Environment

- [VSCode](https://code.visualstudio.com/)
- A terraform provider
- [Golang](https://golang.org/)
- [Golang extension](https://marketplace.visualstudio.com/items?itemName=golang.Go) setup and configured

The environment is also set up in the [Azure Devops devcontainer](https://github.com/terraform-providers/terraform-provider-azuredevops/tree/master/.devcontainer). The code below can also be found in the repository. 

# Set up

Add the `launch.json` and `.env` below. Edit the `.env` file as needed for your terraform provider secrets.

> NB: The `buildFlags` attribute was only needed for Azure Devops provider, for example, the Databricks provider work without it.

`launch.json`
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch a test",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${file}",
            "args": [
                "-test.v",
                "-test.run",
                "^${selectedText}$"
            ],
            "env": {
                "TF_ACC": "1",
            },            
            "buildFlags": "-v -tags=all",
            "showLog": true,
            "envFile": "${workspaceFolder}/.env"
        }
    ]
}
```
`.env`
```json
AZDO_PERSONAL_ACCESS_TOKEN=<your_token>
AZDO_ORG_SERVICE_URL=<your_azdo_org>
```

Make sure `Launch a test` is selected in the VSCode debug window

![Launch debug](/images/debug-tf-vscode/launch-test.png)

# Debug a test

Highlight the name of the test you wish to run test in the test file and press `F5` or select `Start debugging`.

# Debugging in action

![Run debug test](/images/debug-tf-vscode/run-tf-debug.gif)

# Issues

~~The only issue with this solution is that you have to highlight the test name and press `F5` instead of being able to just select the `debug test` option above each test in VSCode. You're able to run non-integration tests via that option and run all tests via the corresponding `run test` option.~~

![Debug test](/images/debug-tf-vscode/debug-test.png)

~~I'd love it if anyone could share a solution where they've got it to work with that.~~

## Fixed: Enable codelens debugging

The missing piece to enable codelens debugging is to add the below flags to `go.testFlags` in `settings.json`

#### **`settings.json`**
```json
{
    "go.testFlags": [
        "-v",
        "-tags=all",
        "-args",
        "-test.v"
    ],
}
```

Huge thanks to [Thomas Meckel](https://twitter.com/tmeckel3) for figuring this out!

# Credit

Inspired by https://blog.gripdev.xyz/2019/09/12/easily-debugging-terraform-provider-for-azure-in-vscode/
