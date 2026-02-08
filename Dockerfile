FROM node:22-slim

# Tools base path (persisted via volume)
ENV TOOLS_DIR=/tools
ENV PATH="${TOOLS_DIR}/npm/bin:${TOOLS_DIR}/go/bin:${TOOLS_DIR}/python/bin:${PATH}"

# System deps + vim + Python + Homebrew deps + headless Chromium + redsocks for proxy
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash ca-certificates curl git vim \
        python3 python3-pip \
        build-essential file procps \
        chromium chromium-sandbox \
        redsocks \
        iptables \
        openssh-server \
        openssh-client \
        docker.io \
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

# Install openclaw to default location (always available, not in volume)
RUN npm install -g openclaw@latest

# Install other npm tools to /tools/npm (persisted via volume)
RUN npm config set prefix ${TOOLS_DIR}/npm \
    && npm install -g clawdhub mcporter @steipete/summarize playwright

# SSH: allow root login by key only, generate host keys
RUN ssh-keygen -A \
    && mkdir -p /etc/ssh/sshd_config.d \
    && echo "PermitRootLogin prohibit-password" > /etc/ssh/sshd_config.d/99-root.conf

# Replace apt-get with a stub so OpenClaw bot gets a clear error and uses brew instead
RUN echo '#!/bin/sh' > /usr/bin/apt-get \
    && echo "echo \"'apt-get' not available, please use 'brew install' instead\" >&2" >> /usr/bin/apt-get \
    && echo 'exit 1' >> /usr/bin/apt-get \
    && chmod +x /usr/bin/apt-get

# Entrypoint: optional redsocks on startup, sshd, then exec CMD
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Declare volumes for persistence (brew, npm, go, python binaries + app data)
VOLUME ["/home/linuxbrew/.linuxbrew", "/tools", "/root/.openclaw", "/root/openclaw", "/root/openclaw", "/root/.gitcfg", "/root/.cache", "/root/.config", "/root/.ssh"]

# Clawdbot host UI port, SSH
EXPOSE 18789
EXPOSE 18791
EXPOSE 22

# Start the Gateway (MoltBot's long-running service)
CMD ["openclaw", "gateway", "--allow-unconfigured", "--bind", "lan"]
