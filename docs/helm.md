# Helm Setup

이 저장소의 Helm 구성은 버전별 Docker base image를 KServe `InferenceService`로 배포하는 데 초점을 둡니다.

MLflow Tracking Server 자체는 공식 MLflow Helm chart를 사용합니다.

```bash
make mlflow-install
make mlflow-status
make mlflow-port-forward
```

접속 주소:

```text
http://localhost:5001
```

공식 chart 기본 이미지는 `ghcr.io/mlflow/mlflow:v3.14.0-full`입니다. 첫 설치 때만 pull이 오래 걸릴 수 있고, 이후에는 kind 노드 캐시를 사용합니다.

## Chart

```text
charts/layered-model
```

배포 리소스:

- `Namespace`
- `ServiceAccount`
- `InferenceService`

## Render

```bash
make helm-template
```

## Install

KServe CRD/controller가 먼저 설치되어 있어야 합니다.

```bash
make deploy LAYER=g4
make deploy LAYER=g5
make deploy LAYER=g6
make helm-install-model
```

## Image Override

```bash
helm upgrade --install layered-model charts/layered-model \
  --namespace model-serving \
  --create-namespace \
  --set image.repository=localhost:8080/library/layered-kserve \
  --set image.tag=u24-cu128-py312-torch210-mlflow3152-kserve0190-g6
```

로컬 kind 클러스터에서 GPU가 없으면 `charts/layered-model/values-local.yaml`처럼 `gpu.enabled=false`를 사용합니다.
