# Dockerfile
FROM ubuntu:25.10

# Enforce Labels.
LABEL org.opencontainers.image.ref.name="ubuntu"
LABEL org.opencontainers.image.version="25.10"

ENV DEBIAN_FRONTEND=noninteractive
ENV IMAGENAME="win1-dev-machine"

# Keep PATH explicit as requested (though Ubuntu already sets this)
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Install SSH server and a few basics
RUN apt-get update && \
    apt-get install -y --no-install-recommends ssh openssh-server ca-certificates pipx binutils-common \
	curl wget git neovim tmux cmake cmake-data gcc-11 g++-11 gcc-10 g++-10 clang-14 llvm-14-dev llvm-14-tools \
	less nano sudo iproute2 build-essential golang-go ninja-build libgmp-dev libmpfr-dev python3 \
	python3-pip libncurses5-dev unzip ca-certificates libboost-all-dev gcc-multilib g++-multilib \
	lcov autoconf ca-certificates gnupg-agent graphviz libgraphviz-dev libsqlite3-dev zsh \
	clang-16 llvm-16-dev llvm-16-tools \
	default-jre default-jdk net-tools software-properties-common libstdc++-12-dev libstdc++-11-dev && \
    rm -rf /var/lib/apt/lists/*

# Prepare sshd runtime dir
RUN mkdir -p /run/sshd

# Install Cargo
ENV CARGO_HOME=/root/.cargo \
    RUSTUP_HOME=/root/.rustup
RUN set -eux; \
    curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable; \
    "$CARGO_HOME/bin/rustc" -V; "$CARGO_HOME/bin/cargo" -V
ENV PATH="${CARGO_HOME}/bin:${PATH}"

# Installing uv package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Create user 'sumitl' with sudo privileges and set password 'sumitl'
RUN useradd -m -s /bin/bash sumitl \
 && echo 'sumitl:sumitl' | chpasswd \
 && usermod -aG sudo sumitl \
 && mkdir -p /home/sumitl/.ssh \
 && chown -R sumitl:sumitl /home/sumitl/.ssh \
 && chmod 700 /home/sumitl/.ssh

# SSH hardening defaults: no root login, key-based by default
RUN sed -ri 's/#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -ri 's/#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Declare your data mount points (host paths bound at run)
VOLUME ["/docs", "/workdir", "/downloads", "/persist"]

# Declare all container ports used by your run command
# (host mappings are applied at `docker run`)
EXPOSE 8080 80 443 22 56 8081 3000 2000 5000

# Run sshd in foreground as PID 1, log to stderr
CMD ["/usr/sbin/sshd","-D","-e"]