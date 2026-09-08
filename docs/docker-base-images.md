# Docker Base Images

Docker image는 `g0~g6` target으로 나뉩니다. 각 target은 독립 태그로 빌드할 수 있어서, CUDA/Python/PyTorch 조합별 base image catalog를 만들 수 있습니다.

## Docker Layer Map

| Layer | Docker target | Content |
| --- | --- | --- |
| `g0` | `g0-ubuntu` | Ubuntu base |
| `g1` | `g1-cuda` | NVIDIA CUDA runtime |
| `g2` | `g2-python` | Python virtualenv and build tools |
| `g3` | `g3-pytorch` | PyTorch, torchvision, torchaudio |
| `g4` | `g4-mlflow` | MLflow |
| `g5` | `g5-kserve` | KServe Python ModelServer |
| `g6` | `g6-id` | Non-root runtime user and entrypoint |

## Version Sets

Version set files live in `versions/*.env`.

```bash
make list-version-sets
```

Current presets:

| Version set | Ubuntu | CUDA image | Python | PyTorch | MLflow | KServe Python |
| --- | --- | --- | --- | --- | --- | --- |
| `u24-cu128-py312-torch210-mlflow3152-kserve0190` | 24.04 | `nvidia/cuda:12.8.2-runtime-ubuntu24.04` | 3.12 | 2.10.0/cu128 | 3.15.2 | 0.19.0 |
| `u24-cu128-py312-torch270-mlflow3152-kserve0190` | 24.04 | `nvidia/cuda:12.8.2-runtime-ubuntu24.04` | 3.12 | 2.7.0/cu128 | 3.15.2 | 0.19.0 |
| `u24-cu126-py312-torch270-mlflow3152-kserve0190` | 24.04 | `nvidia/cuda:12.6.3-runtime-ubuntu24.04` | 3.12 | 2.7.0/cu126 | 3.15.2 | 0.19.0 |
| `u22-cu128-py310-torch270-mlflow3152-kserve0190` | 22.04 | `nvidia/cuda:12.8.2-runtime-ubuntu22.04` | 3.10 | 2.7.0/cu128 | 3.15.2 | 0.19.0 |

## Build

Build one layer for one version set:

```bash
IMAGE_REPO=ghcr.io/your-org/layered-kserve \
PUSH=true \
make build-base VERSION_SET=u24-cu128-py312-torch210-mlflow3152-kserve0190 LAYER=g3
```

Build all layers for one version set:

```bash
IMAGE_REPO=ghcr.io/your-org/layered-kserve \
PUSH=true \
make build-base VERSION_SET=u24-cu128-py312-torch210-mlflow3152-kserve0190 LAYER=all
```

Build every preset:

```bash
IMAGE_REPO=ghcr.io/your-org/layered-kserve \
PUSH=true \
make build-base-all LAYER=all
```

Output tags follow this pattern:

```text
<IMAGE_REPO>:<VERSION_SET>-<LAYER>
```

Example:

```text
ghcr.io/your-org/layered-kserve:u24-cu128-py312-torch210-mlflow3152-kserve0190-g6
```

## BuildKit In Cluster

If `g3-buildkit` infra is deployed, port-forward the service and build through BuildKit:

```bash
kubectl -n buildkit port-forward svc/buildkitd 1234:1234
BUILDCTL_ADDR=tcp://127.0.0.1:1234 \
IMAGE_REPO=ghcr.io/your-org/layered-kserve \
PUSH=true \
make build-base VERSION_SET=u24-cu128-py312-torch210-mlflow3152-kserve0190 LAYER=all
```
