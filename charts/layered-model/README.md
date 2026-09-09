# layered-model Helm Chart

KServe `InferenceService`를 배포하는 Helm chart입니다.

## Render

```bash
helm template layered-model charts/layered-model -f charts/layered-model/values-local.yaml
```

## Install

```bash
helm upgrade --install layered-model charts/layered-model \
  -f charts/layered-model/values-local.yaml \
  --namespace model-serving \
  --create-namespace
```

## Image

기본 이미지는 로컬 Harbor를 가리킵니다.

```text
localhost:8080/library/layered-kserve:u24-cu128-py312-torch210-mlflow3152-kserve0190-c269b4c78ded-g6
```
