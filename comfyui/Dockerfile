# Parameterized ComfyUI image — one build per app (krea2, ideogram, ltx).
#
# Each app under apps/<name>/ declares what makes it unique:
#   nodes.txt        custom nodes to bake in (dir url [git-ref])
#   constraints.txt  pip version pins protected during every install
#   extras.txt       additional pip packages the app's workflow needs
#   models.txt       model files (downloaded at container start, NOT here)
#   check.sh         optional build-time sanity check
#   workflows/       optional workflow JSONs seeded into the UI
#
# NOTE: the RunPod reference scripts for ideogram/ltx pin torch 2.4.0+cu121,
# which has no Blackwell (RTX 50xx / sm_120) kernels and cannot run on this
# machine. All apps here use the cu128 stack instead (krea2's own pin, and
# xformers is dropped for ltx — ComfyUI's native attention covers it).

ARG CUDA_IMAGE=nvidia/cuda:12.8.1-devel-ubuntu24.04

FROM ${CUDA_IMAGE}

# ---- version pins -----------------------------------------------------------
ARG APP
ARG COMFY_REF=master
ARG CUDA_STREAM=cu128
ARG TORCH_VERSION=2.8.0
ARG TORCHVISION_VERSION=0.23.0
ARG TORCHAUDIO_VERSION=2.8.0
# -----------------------------------------------------------------------------

ENV DEBIAN_FRONTEND=noninteractive
ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 10.0 12.0"

RUN apt-get update && apt-get install --no-install-recommends -y \
    git \
    git-lfs \
    curl \
    ca-certificates \
    build-essential \
    cmake \
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
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PYTHONNOUSERSITE=1

RUN pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/${CUDA_STREAM} \
    torch==${TORCH_VERSION} \
    torchvision==${TORCHVISION_VERSION} \
    torchaudio==${TORCHAUDIO_VERSION}

# Full constraints = locked torch stack + the app's own pins. Every pip
# install below goes through this file so nothing can replace the GPU stack
# (same idea as the reference scripts' constraint/sanitizer machinery).
COPY apps/${APP}/constraints.txt /opt/app/app-constraints.txt
RUN { \
      echo "torch==${TORCH_VERSION}+${CUDA_STREAM}"; \
      echo "torchvision==${TORCHVISION_VERSION}+${CUDA_STREAM}"; \
      echo "torchaudio==${TORCHAUDIO_VERSION}+${CUDA_STREAM}"; \
      cat /opt/app/app-constraints.txt; \
    } > /opt/app/constraints.txt

# ComfyUI core at the pinned ref. CACHEBUST forces re-clone when tracking a
# moving ref like master (make upgrade sets it).
ARG CACHEBUST=0
RUN echo "cachebust: ${CACHEBUST}" && \
    git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui && \
    git -C /comfyui checkout "${COMFY_REF}" && \
    git -C /comfyui rev-parse HEAD > /opt/app/comfyui-commit.txt

WORKDIR /comfyui

RUN pip install --no-cache-dir --prefer-binary \
    -c /opt/app/constraints.txt -r requirements.txt

# Custom nodes: clone + install their requirements through the sanitizer
# (strips torch/transformers/opencv/etc. lines so the locked stack survives).
COPY sanitize-reqs.py install-nodes.sh /opt/app/
COPY apps/${APP}/nodes.txt /opt/app/nodes.txt
RUN bash /opt/app/install-nodes.sh /opt/app/nodes.txt

# App-specific extra packages (workflow dependencies).
COPY apps/${APP}/extras.txt /opt/app/extras.txt
RUN xargs -a /opt/app/extras.txt -r pip install --no-cache-dir --prefer-binary \
    -c /opt/app/constraints.txt

# Runtime manifests + optional build-time sanity check.
COPY apps/${APP}/ /opt/app/appdir/
RUN if [ -x /opt/app/appdir/check.sh ]; then /opt/app/appdir/check.sh; fi

EXPOSE 8188

# Keep the writable layer clean: all caches and downloads go to /data volumes.
ENV HF_HOME=/data/cache/huggingface \
    TORCH_HOME=/data/cache/torch \
    XDG_CACHE_HOME=/data/cache/xdg

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
