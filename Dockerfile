# ai-toolkit (ostris/ai-toolkit) — local NVIDIA GPU image
#
# All version pins live in the ARG block below. See docs/UPGRADING.md for how
# and when to bump each one.
#
# Layer strategy (mirrors upstream docker/Dockerfile): heavy dependencies
# (torch, python requirements, node_modules) are installed from the pinned
# ref's manifests BEFORE the source clone, so routine upgrades only rebuild
# the small source + UI-build layers.

ARG CUDA_IMAGE=nvidia/cuda:12.8.1-devel-ubuntu24.04

FROM ${CUDA_IMAGE}

# ---- version pins -----------------------------------------------------------
# Git ref (branch, tag, or commit sha) of ostris/ai-toolkit to install.
ARG AI_TOOLKIT_REF=main
# PyTorch wheel set. CUDA_STREAM cu128 is required for Blackwell (RTX 50xx);
# use cu126 for older cards. Keep the three versions in lockstep.
ARG CUDA_STREAM=cu128
ARG TORCH_VERSION=2.9.1
ARG TORCHVISION_VERSION=0.24.1
ARG TORCHAUDIO_VERSION=2.9.1
# Node.js major version for the UI (NodeSource).
ARG NODE_MAJOR=22
# -----------------------------------------------------------------------------

ENV DEBIAN_FRONTEND=noninteractive
# Compute capabilities for source-built CUDA extensions (12.0 = Blackwell).
ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 10.0 12.0"
# All persistent state (models, datasets, outputs, db) lives under /data,
# which docker-compose bind-mounts to ./data on the host.
ENV HF_HOME=/data/hf-cache

RUN apt-get update && apt-get install --no-install-recommends -y \
    git \
    curl \
    ca-certificates \
    build-essential \
    cmake \
    rsync \
    unzip \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-setuptools \
    python3-wheel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python

# Torch first: it is the largest download and changes least often.
RUN pip install --no-cache-dir --break-system-packages \
    --index-url https://download.pytorch.org/whl/${CUDA_STREAM} \
    torch==${TORCH_VERSION} \
    torchvision==${TORCHVISION_VERSION} \
    torchaudio==${TORCHAUDIO_VERSION}

WORKDIR /app/ai-toolkit

# Python requirements from the pinned ref (layer busts when AI_TOOLKIT_REF changes).
RUN curl -fsSL "https://raw.githubusercontent.com/ostris/ai-toolkit/${AI_TOOLKIT_REF}/requirements.txt" -o requirements.txt && \
    pip install --no-cache-dir --break-system-packages -r requirements.txt

# UI node_modules from the pinned ref's lockfile.
RUN mkdir -p ui && cd ui && \
    curl -fsSL "https://raw.githubusercontent.com/ostris/ai-toolkit/${AI_TOOLKIT_REF}/ui/package.json" -o package.json && \
    curl -fsSL "https://raw.githubusercontent.com/ostris/ai-toolkit/${AI_TOOLKIT_REF}/ui/package-lock.json" -o package-lock.json && \
    npm ci --no-audit --fund=false

# Source code last. CACHEBUST forces a fresh clone when tracking a moving
# branch like `main` (make upgrade sets it to the current timestamp).
ARG CACHEBUST=0
RUN echo "cachebust: ${CACHEBUST}" && \
    git clone https://github.com/ostris/ai-toolkit.git /tmp/src && \
    git -C /tmp/src checkout "${AI_TOOLKIT_REF}" && \
    git -C /tmp/src rev-parse HEAD > /app/ai-toolkit-commit.txt && \
    rsync -a --delete \
        --exclude 'ui/node_modules' \
        --exclude 'requirements.txt' \
        --exclude 'ui/package.json' \
        --exclude 'ui/package-lock.json' \
        /tmp/src/ /app/ai-toolkit/ && \
    rm -rf /tmp/src

# prisma generate (creates the client types) + Next.js production build.
RUN cd ui && npm run update_db && npm run build

EXPOSE 8675

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "run", "start", "--prefix", "/app/ai-toolkit/ui"]
