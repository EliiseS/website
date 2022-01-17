FROM debian:10-slim

ARG HUGO_VERSION=0.92.0

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
    && npm install npm@latest -g \
    # Install prettier
    && npm install prettier prettier-plugin-go-template -g \
    # Install markdown linters
    && npm install markdown-spellcheck -g \
    && npm install markdown-link-check -g \
    && npm install markdownlint-cli -g 

# Customize bash
RUN \
    # Git command prompt
    git clone https://github.com/magicmonty/bash-git-prompt.git ~/.bash-git-prompt --depth=1 && \
    echo "if [ -f \"$HOME/.bash-git-prompt/gitprompt.sh\" ]; then GIT_PROMPT_ONLY_IN_REPO=1 && source $HOME/.bash-git-prompt/gitprompt.sh; fi" >> "/root/.bashrc" && \
    # Install bash completion
    apt-get update && \
    apt-get -y install bash-completion && \
    echo "source /usr/share/bash-completion/bash_completion" >> ~/.bashrc 

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
