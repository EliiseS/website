---
title: "Testing terraform with Pester"
date: 2020-06-06T08:06:25+06:00
lastmod: 2020-06-08T08:06:25+06:00
draft: false
toc: true
categories: [terraform, pester, testing]
noSummary: true
---

In this post I'd like show how you can create integrations tests for terraform with [Pester](https://github.com/pester/Pester), a powershell testing framework.

In this example I'll be using the [Azure DevOps terraform provider](https://www.terraform.io/docs/providers/azuredevops/index.html) along with the [Azure Devops CLI](https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops), but these are just examples that can be replaced as needed for your tests.

All code snippets can be found in [terraform-pester-devcontainer-example](https://github.com/EliiseS/terraform-pester-devcontainer-example) repository.

# Environment

- [Pester](https://github.com/pester/Pester) 4.10.1
- Powershell Core
- Terraform
- [Azure DevOps terraform provider](https://www.terraform.io/docs/providers/azuredevops/index.html)
- [Azure Devops CLI](https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops)
- OS: Debian Buster

# Terraform under test

The terraform below will be creating a project, a repository and a variable group

#### **`main.tf`**

```hcl
provider "azuredevops" {
  version = ">= 0.0.1"
}

resource "azuredevops_project" "test" {
  project_name = "test-project"
}

resource "azuredevops_git_repository" "test" {
  project_id = azuredevops_project.test.id
  name       = "test-repo"
  initialization {
    init_type = "Clean"
  }
}

resource "azuredevops_variable_group" "test" {
  project_id   = azuredevops_project.test.id
  name         = "test-vg"
  allow_access = true

  variable {
    name  = "example_var_name"
    value = "example_var_value"
  }
}
```

# Pester tests

The tests will:

1. apply terraform
1. check validity of state against `az devops CLI`
1. tear down the deployed infrastructure

#### **`tfIntegration.tests.ps1`**

```powershell
function Get-ResourceState($address) {
    # Get state and resources after `terraform apply`
    $tfState = terraform show -json | ConvertFrom-Json
    $resources = $tfState.values.root_module.resources

    return $resources | Where-Object { $_.address -eq $address }
}

function Get-Project {
    return Get-ResourceState "azuredevops_project.test"
}

function Get-Repository {
    return Get-ResourceState "azuredevops_git_repository.test"
}

function Get-VariableGroup {
    return Get-ResourceState "azuredevops_variable_group.test"
}

Describe "Terraform Deployment" -Tag 'Deploy' {
    Context "clean tfstate" {

        It "remove tfstate" {
            $tfStatePath = "./terraform.tfstate"
            if (Test-Path $tfStatePath -PathType leaf) {
                Remove-Item $tfStatePath -Force
            }
        }

        It "terraform initialize" {
            terraform init
        }

        It "terraform apply" {
            $tfResult = terraform apply -auto-approve
            $LASTEXITCODE | Should -Be 0
            Write-Host $tfResult
        }

        It "returns state for all resources" {
            Get-Project | Should -Not -BeNullOrEmpty
            Get-Repository | Should -Not -BeNullOrEmpty
            Get-VariableGroup | Should -Not -BeNullOrEmpty
        }

        It "returns a valid repostiory for the repository ID" {
            $repository = Get-Repository
            $repository.values.id | Should -Not -BeNullOrEmpty
            az repos show -r $repository.values.id -p $repository.values.project_id --org ${env:AZDO_ORG_SERVICE_URL}
            $LASTEXITCODE | Should -Be 0
        }

        It "returns a valid variableGroup for the variableGroup ID" {
            $variableGroup = Get-VariableGroup
            $variableGroup.values.id | Should -Not -BeNullOrEmpty
            az pipelines variable-group show --id $variableGroup.values.id -p $variableGroup.values.project_id --org ${env:AZDO_ORG_SERVICE_URL}
            $LASTEXITCODE | Should -Be 0
        }

        It "returns an empty plan when re-run" {
            # Run a terraform plan and check no changes are detected
            # `-detailed-exitcode` will cause the command to exit with 0 exit code
            # only if there are no diffs in the plan
            # https://www.terraform.io/docs/commands/plan.html#detailed-exitcode
            #
            # If this test fails it shows an issue with the `read` command returning different data between calls.

            terraform plan -out plan.tfstate -detailed-exitcode

            if ($LASTEXITCODE -ne 0) {
                Write-Host "Detected terraform changes:"
                terraform show plan.tfstate
            }

            $LASTEXITCODE | Should -Be 0 -Because "plan should show no changes"
        }
    }
}

Describe "Terraform Destroy" -Tag 'Destroy' {
    Context "existing tfstate" {

        It "ensure we have an existing terraform deployment" {
            "./terraform.tfstate" | Should -Exist
        }

        It "terraform destroy" {
            $tfResult = terraform destroy -auto-approve
            $LASTEXITCODE | Should -Be 0
            Write-Host $tfResult

        }

        It "clean up terraform files" {
            Remove-Item ./terraform.tfstate -Force
            Remove-Item ./terraform.tfstate.backup -Force
            Remove-Item ./plan.tfstate -Force
        }
    }
}
```

## Run with

```sh
Invoke-Pester
# OR
./tfIntegration.tests.ps1
```
