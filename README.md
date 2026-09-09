# Layered Kubernetes Platform Deploy

`g0`부터 `g6`까지 레이어별로 Argo CD, Argo Workflows, BuildKit, KServe를 배포하는 GitOps 스캐폴드입니다.

## Layer Map

| Layer | Name | Purpose |
| --- | --- | --- |
| `g0` | bootstrap | 공통 namespace와 레이어 메타데이터 |
| `g1` | argocd | Argo CD 컨트롤 플레인 |
| `g2` | argo-workflows | Argo Workflows controller/server |
| `g3` | buildkit | Kubernetes 내부 rootless BuildKit daemon |
| `g4` | kserve-crds | KServe CRD |
| `g5` | kserve-controller | KServe controller/resources |
| `g6` | kserve-runtimes | KServe built-in ClusterServingRuntime |

## Quick Start

현재 kube-context를 확인한 뒤 원하는 레이어를 올립니다.

```bash
kubectl config current-context
make deploy LAYER=g0
make deploy LAYER=g1
make deploy LAYER=g2
make deploy LAYER=g3
make deploy LAYER=g4
make deploy LAYER=g5
make deploy LAYER=g6
```

전체 순차 배포:

```bash
make deploy
```

Argo CD가 이후 레이어를 GitOps로 관리하게 하려면 Git repository URL을 넘겨 app-of-apps를 적용합니다.

```bash
make deploy-gitops
```

## Defaults

| Variable | Default |
| --- | --- |
| `CLUSTER` | `dev` |
| `KSERVE_VERSION` | `v0.20.0` |
| `KSERVE_MODE` | `Standard` |
| `CERT_MANAGER_VERSION` | `v1.17.0` |
| `METRICS_SERVER_VERSION` | `v0.8.1` |
| `ARGO_WORKFLOWS_VERSION` | `v4.1.2` |
| `ARGOCD_MANIFEST_URL` | `https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml` |

KServe는 기본값으로 Knative/Istio 없이 Raw Kubernetes 배포를 쓰는 `Standard` 모드로 설정합니다.

## Validate

로컬 Kustomize 레이어 렌더링 확인:

```bash
make validate
```

클러스터 리소스 상태 확인:

```bash
make status
```

## BuildKit Usage

BuildKit 서비스는 `buildkit` namespace의 `buildkitd:1234`로 열립니다.

```bash
kubectl -n buildkit port-forward svc/buildkitd 1234:1234
buildctl --addr tcp://127.0.0.1:1234 debug workers
```

운영 환경에서는 BuildKit TCP endpoint에 mTLS 또는 네트워크 제한을 추가하는 것을 권장합니다.

## Versioned Base Images

Docker base image는 `g0~g6` target으로 나뉩니다.

| Layer | Content |
| --- | --- |
| `g0` | Ubuntu |
| `g1` | CUDA |
| `g2` | Python |
| `g3` | PyTorch |
| `g4` | MLflow |
| `g5` | KServe ModelServer |
| `g6` | non-root runtime id |

버전 세트 목록:

```bash
make list-version-sets
```

특정 버전 세트의 전체 base image 빌드:

```bash
IMAGE_REPO=ghcr.io/your-org/layered-kserve \
PUSH=true \
make build-base VERSION_SET=u24-cu128-py312-torch210-mlflow3152-kserve0190 LAYER=all
```

자세한 내용은 [docs/docker-base-images.md](docs/docker-base-images.md)를 봅니다.

## Helm

MLflow Tracking Server는 공식 MLflow Helm chart로 배포하고, KServe 모델 배포 Helm chart는 `charts/layered-model`에 있습니다.

MLflow 설치:

```bash
make mlflow-install
make mlflow-port-forward
```

MLflow UI:

```text
http://localhost:5001
```

YOLO11n 모델을 MLflow Registry에 등록하고 예측을 검증합니다.

```bash
make mlflow-yolo-test
```

```bash
make helm-template
make helm-install-model
```

로컬 배포 이미지는 `charts/layered-model/values-local.yaml`에 기록된 Harbor 태그를 사용합니다.

자세한 내용은 [docs/helm.md](docs/helm.md)를 봅니다.

## CI/CD

Argo Workflows가 Git 소스를 빌드해 Harbor에 저장하고, Helm values를 갱신하면 Argo CD가 KServe 모델을 자동 배포합니다.

```bash
GIT_USERNAME=<username> GIT_TOKEN=<token> make cicd-install
GIT_REPO_URL=https://github.com/choijinwon/devopsAgent.git make cicd-run
make cicd-status
```

특정 Docker 레이어만 빌드할 때는 `LAYER=g0`부터 `LAYER=g6` 중 하나를 지정합니다. `LAYER=all`은 전체 레이어를 빌드하고 최종 `g6` 이미지를 배포합니다.

자세한 내용은 [docs/cicd.md](docs/cicd.md)를 봅니다.

## Local Harbor

로컬 Harbor registry 설치:

```bash
make install-harbor
```

기본 접속 정보:

| Item | Value |
| --- | --- |
| URL | `http://localhost:8080` |
| Username | `admin` |
| Password | `Harbor12345` |

베이스 이미지 저장소로 Harbor를 쓰려면:

```bash
docker login localhost:8080
PUSH=true make build-base VERSION_SET=u24-cu128-py312-torch210-mlflow3152-kserve0190 LAYER=all
```

## Argo Workflows Usage

Argo Workflows UI는 `argo` namespace의 `argo-server:2746`에서 열립니다.

```bash
make argo-workflows-port-forward
```

브라우저에서 `https://127.0.0.1:2746`으로 접근합니다. 자체 서명 인증서 경고가 보일 수 있습니다.

## Notes

- Argo CD 공식 getting started 문서는 CRD 크기 이슈 때문에 server-side apply와 force-conflicts를 사용합니다.
- Argo Workflows 공식 설치 문서는 프로덕션에서 특정 release version의 manifest를 쓰라고 안내합니다.
- KServe `v0.20.0` 문서는 Helm OCI 차트와 release YAML 둘 다 제공하며, 이 저장소의 로컬 배포 스크립트는 release YAML을 사용합니다.
- BuildKit 공식 Kubernetes 예제는 rootless 변형을 권장합니다. 이 저장소도 rootless daemon 배포를 기본으로 둡니다.
