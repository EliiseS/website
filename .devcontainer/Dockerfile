FROM debian:10-slim

ARG HUGO_VERSION=0.74.2

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install packages
RUN apt update \
    && apt -y install --no-install-recommends apt-utils dialog wget ca-certificates 2>&1 \
    # Verify git, process tools, lsb-release (common in install instructions for CLIs) installed
    && apt -y install git procps lsb-release unzip build-essential \
    # Install missing icu-devtools to be able to use liveshare. More info: https://stackoverflow.com/questions/58736399/how-to-get-vscode-liveshare-extension-working-when-running-inside-vscode-remote
    && apt install icu-devtools -y \
    #
    # Clean up
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install hugo
RUN wget -O hugo.deb https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.deb \
    && dpkg -i hugo.deb

# Install nodejs npm
RUN apt update \
    && apt -y install nodejs npm \
    # Install prettier
    && npm install prettier prettier-plugin-go-template -D --save-exact 

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
