---
title: "PowerShell Core as default shell on a Debian devcontainer"
date: 2020-06-08T08:06:25+06:00
publishdate: 2020-06-08T08:06:25+06:00
lastmod: 2020-06-08T08:06:25+06:00
series: ["devcontainer"]
draft: false
toc: true
img: "images/background/sunset.jpg"
categories: ["powershell", "devcontainer"]

---

Here we'll cover setting up powershell on a dev container with a `debian:buster` baseimage.

At the bottom of this article you can also find the full [devcontainer.json](#devcontainerjson) and [dockerimage](#dockerimage), which you can skip to.

Credit to: https://www.phillipsj.net/posts/powershell-as-default-shell-on-ubuntu/

# Installing Powershell 7

Here's the PowerShell install snippet from our debian dockerfile.

```Dockerfile
# Install PowerShell 7
RUN wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
```

# Set PowerShell as default shell

Next to set powershell as our default shell we must find it in the list of available shells with:

```bash
$ cat /etc/shells
# /etc/shells: valid login shells
/bin/sh
/bin/bash
/bin/rbash
/bin/dash
/usr/bin/pwsh
/opt/microsoft/powershell/7/pwsh
```

The last item in the list is the PowerShell shell location, which we need to use in our `devcontainer.json` file to set it as our default shell.

```json
"settings": {
		"terminal.integrated.shell.linux": "/opt/microsoft/powershell/7/pwsh",
	},
```

# Optional PowerShell profile set up

If you want to be able to customize your PowerShell like you would with bash, such as to add aliases, you can set up a profile using the below.

```Dockerfile
# Powershell customization
RUN \
    ## Create PS profile
    pwsh -c 'New-Item -Path $profile -ItemType File -Force' \
    ## Add alias
    && pwsh -c "'New-Alias \"tf\" \"terraform\"' | Out-File -FilePath \$profile"
```


# Complete files

## Dockerimage

```Dockerfile
FROM debian:buster

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils 2>&1 \
    # Verify git, process tools, lsb-release (common in install instructions for CLIs), wget installed
    && apt-get -y install git procps lsb-release wget \
    # Install Editor
    && apt-get install vim -y \
    # Install PowerShell 7
    && wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y powershell \
    #
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Powershell customization
RUN \
    ## Create PS profile
    pwsh -c 'New-Item -Path $profile -ItemType File -Force' \
    ## Add alias
    && pwsh -c "'New-Alias \"tf\" \"terraform\"' | Out-File -FilePath \$profile"

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
```

## devcontainer.json

```json
{
	"name": "Debian 10 & PowerShell",
	"dockerFile": "Dockerfile",
	// Set *default* container specific settings.json values on container create.
	"settings": {
		"terminal.integrated.shell.linux": "/opt/microsoft/powershell/7/pwsh",
	},
	// Add the IDs of extensions you want installed when the container is created.
	"extensions": [
		"ms-vscode.powershell"
	]
}
```


# Known issues

These are the issues that I've run into:

- PowerShell Core has fewer modules and commands available when compared to Powershell
- `Remove-Item` command has been unusable due to exasperated results with a known issue: https://github.com/PowerShell/PowerShell/issues/8211

