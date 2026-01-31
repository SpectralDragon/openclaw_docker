FROM node:22-slim

# Tools base path (persisted via volume)
ENV TOOLS_DIR=/tools
ENV PATH="${TOOLS_DIR}/npm/bin:${TOOLS_DIR}/go/bin:${TOOLS_DIR}/python/bin:${PATH}"

# System deps + vim + Python + Homebrew deps + headless Chromium for automation
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash ca-certificates curl git vim \
        python3 python3-pip \
        build-essential file procps \
        chromium chromium-sandbox \
    && rm -rf /var/lib/apt/lists/*

# Symlink python -> python3, pip -> pip3 for convenience
RUN ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Create /tools structure for npm, go, python (persisted via volume)
RUN mkdir -p ${TOOLS_DIR}/npm ${TOOLS_DIR}/go/bin ${TOOLS_DIR}/python

# Create linuxbrew user (Homebrew expects non-root on Linux)
RUN useradd -m -s /bin/bash linuxbrew

# Install Homebrew + brew packages as linuxbrew user (to default path, persisted via volume)
USER linuxbrew
WORKDIR /home/linuxbrew
RUN curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/brew-install.sh \
    && NONINTERACTIVE=1 /bin/bash /tmp/brew-install.sh \
    && rm /tmp/brew-install.sh \
    && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" \
    && brew tap yakitrak/yakitrak \
    && brew install gh himalaya yakitrak/yakitrak/obs

# Back to root, add Homebrew and tools to PATH
USER root
WORKDIR /root
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

# Env vars for Go and Python (when used: go install, pip install --user)
ENV GOPATH=${TOOLS_DIR}/go
ENV GOBIN=${TOOLS_DIR}/go/bin
ENV PYTHONUSERBASE=${TOOLS_DIR}/python

# Install npm tools to /tools/npm (persisted via volume)
RUN npm config set prefix ${TOOLS_DIR}/npm \
    && npm install -g openclaw@latest clawdhub mcporter @steipete/summarize playwright

# Declare volumes for persistence (brew, npm, go, python binaries + app data)
VOLUME ["/home/linuxbrew/.linuxbrew", "/tools", "/root/.openclaw", "/root/openclaw", "/root/openclaw", "/root/.gitcfg", "/root/.cache", "/root/.config"]

# Clawdbot host UI port
EXPOSE 18789
EXPOSE 18791

# Start the Gateway (MoltBot's long-running service)
CMD ["sh", "-c", "cp ~/.gitcfg/.gitconfig ~/.gitconfig 2>/dev/null || true && openclaw gateway --allow-unconfigured --bind lan"]
