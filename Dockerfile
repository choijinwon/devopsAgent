# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04
ARG CUDA_IMAGE=nvidia/cuda:12.8.2-runtime-ubuntu24.04
ARG PYTHON_PACKAGE=python3.12
ARG PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cu128
ARG PYTORCH_VERSION=2.10.0
ARG TORCHVISION_VERSION=0.25.0
ARG TORCHAUDIO_VERSION=2.10.0
ARG MLFLOW_VERSION=3.15.2
ARG KSERVE_PYTHON_VERSION=0.19.0
ARG APP_UID=10001
ARG APP_GID=10001
ARG APP_USER=model

FROM ubuntu:${UBUNTU_VERSION} AS g0-ubuntu
ARG UBUNTU_VERSION
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      tini \
      tzdata \
    && rm -rf /var/lib/apt/lists/*
LABEL org.opencontainers.image.layer.g0="ubuntu" \
      org.opencontainers.image.version.ubuntu="${UBUNTU_VERSION}"

FROM ${CUDA_IMAGE} AS g1-cuda
ARG CUDA_IMAGE
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      tini \
      tzdata \
    && rm -rf /var/lib/apt/lists/*
LABEL org.opencontainers.image.layer.g1="cuda" \
      org.opencontainers.image.version.cuda.image="${CUDA_IMAGE}"

FROM g1-cuda AS g2-python
ARG PYTHON_PACKAGE
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      git \
      ${PYTHON_PACKAGE} \
      ${PYTHON_PACKAGE}-dev \
      ${PYTHON_PACKAGE}-venv \
      python3-pip \
    && rm -rf /var/lib/apt/lists/*
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
RUN "${PYTHON_PACKAGE}" -m venv "${VIRTUAL_ENV}" \
    && pip install --no-cache-dir --upgrade pip setuptools wheel
LABEL org.opencontainers.image.layer.g2="python" \
      org.opencontainers.image.version.python.package="${PYTHON_PACKAGE}"

FROM g2-python AS g3-pytorch
ARG PYTORCH_INDEX_URL
ARG PYTORCH_VERSION
ARG TORCHVISION_VERSION
ARG TORCHAUDIO_VERSION
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
      "torch==${PYTORCH_VERSION}" \
      "torchvision==${TORCHVISION_VERSION}" \
      "torchaudio==${TORCHAUDIO_VERSION}" \
      --index-url "${PYTORCH_INDEX_URL}"
RUN python - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.version.cuda)
PY
LABEL org.opencontainers.image.layer.g3="pytorch" \
      org.opencontainers.image.version.pytorch="${PYTORCH_VERSION}" \
      org.opencontainers.image.version.torchvision="${TORCHVISION_VERSION}" \
      org.opencontainers.image.version.torchaudio="${TORCHAUDIO_VERSION}"

FROM g3-pytorch AS g4-mlflow
ARG MLFLOW_VERSION
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install "mlflow==${MLFLOW_VERSION}"
LABEL org.opencontainers.image.layer.g4="mlflow" \
      org.opencontainers.image.version.mlflow="${MLFLOW_VERSION}"

FROM g4-mlflow AS g5-kserve
ARG KSERVE_PYTHON_VERSION
WORKDIR /opt/model-server
COPY src/model_server.py /opt/model-server/model_server.py
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install "kserve==${KSERVE_PYTHON_VERSION}"
ENV MODEL_NAME=layered-model \
    HTTP_PORT=8080
EXPOSE 8080
LABEL org.opencontainers.image.layer.g5="kserve-model-server" \
      org.opencontainers.image.version.kserve.python="${KSERVE_PYTHON_VERSION}"

FROM g5-kserve AS g6-id
ARG APP_UID
ARG APP_GID
ARG APP_USER
RUN groupadd --gid "${APP_GID}" "${APP_USER}" \
    && useradd --uid "${APP_UID}" --gid "${APP_GID}" --create-home --shell /usr/sbin/nologin "${APP_USER}" \
    && chown -R "${APP_UID}:${APP_GID}" /opt/model-server
USER ${APP_UID}:${APP_GID}
ENTRYPOINT ["tini", "--"]
CMD ["python", "/opt/model-server/model_server.py"]
LABEL org.opencontainers.image.layer.g6="runtime-identity" \
      org.opencontainers.image.title="layered-kserve-mlflow-pytorch" \
      org.opencontainers.image.description="Ubuntu, CUDA, Python, PyTorch, MLflow, KServe model server, and non-root identity layers"
