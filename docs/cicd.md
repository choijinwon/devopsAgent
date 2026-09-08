# Argo CI/CD

이 파이프라인은 Git 소스를 받아 Docker `g0~g6` 이미지를 BuildKit으로 빌드하고 Harbor에 푸시한 뒤, Helm values의 이미지 태그를 Git에 커밋합니다. Argo CD는 해당 변경을 감지해 KServe `InferenceService`를 자동 동기화합니다.

## Pipeline

```text
Git clone -> BuildKit(g0~g6) -> Harbor -> Helm values commit -> Argo CD -> KServe
```

이미지 태그는 다음 형식을 사용합니다.

```text
<version-set>-<git-sha>-<layer>
```

## Install

공개 Git 저장소에서 CI 빌드만 수행할 때:

```bash
make cicd-install
```

일반 Kubernetes에서 rootless BuildKit까지 함께 설치하려면 다음을 사용합니다.

```bash
INSTALL_BUILDKIT=true make cicd-install
```

Docker Desktop의 kind 클러스터는 rootless BuildKit의 사용자 namespace 생성을 차단할 수 있습니다. 이 경우 BuildKit Pod 하나에만 `AppArmor: Unconfined`, `allowPrivilegeEscalation: true`, `SETUID`, `SETGID` capability를 적용해야 하며, 해당 Pod의 커널 격리가 약해집니다. 컨테이너 전체를 `privileged`로 실행하지는 않습니다.

```bash
make cicd-enable-kind-buildkit
```

로컬 개발 전용으로만 사용하고 공유 또는 운영 클러스터에서는 사용하지 않습니다.

Harbor 관리자 비밀번호는 `local/harbor/admin-password`에서 읽습니다. `HARBOR_PASSWORD` 환경 변수를 지정하면 해당 값이 우선합니다.

비공개 저장소 또는 CD까지 수행할 때는 Git에 push 가능한 토큰을 함께 설정합니다.

```bash
GIT_USERNAME=<username> \
GIT_TOKEN=<token> \
make cicd-install
```

토큰에는 대상 저장소의 내용을 읽고 커밋을 push할 권한이 필요합니다. `main`이 보호된 브랜치라면 별도의 배포 브랜치를 사용하고 Argo CD의 `targetRevision`도 같은 브랜치로 설정합니다.

## Run

전체 레이어를 빌드하고 `g6` 모델 이미지를 배포합니다.

```bash
GIT_REPO_URL=https://github.com/choijinwon/devopsAgent.git make cicd-run
```

특정 레이어만 빌드합니다. `g0~g5`는 Harbor push까지만 수행하고, `g6` 또는 `all`은 Helm values 갱신까지 수행합니다.

```bash
GIT_REPO_URL=https://github.com/choijinwon/devopsAgent.git \
LAYER=g3 \
VERSION_SET=u24-cu128-py312-torch210-mlflow3152-kserve0190 \
make cicd-run
```

상태 확인:

```bash
make cicd-status
```

원격 Git 없이 로컬에서 `g0` 빌드와 Harbor push 경로를 확인하려면 다음 smoke test를 사용합니다. 임시 Git 저장소에는 Dockerfile과 선택한 버전 파일만 포함되며 실행이 끝나면 서버가 종료됩니다.

```bash
make cicd-smoke
```

Argo UI에서 YAML을 직접 제출할 때는 `k8s/argo-workflow-build-layers.yaml`을 사용합니다. 이 예제는 `local-pipeline` entrypoint를 사용하므로 Git 주소 없이 현재 설치 시점의 Dockerfile로 `g0`를 빌드합니다. 전체 빌드는 `layer` 값을 `all`로 바꿀 수 있지만 CUDA와 PyTorch 이미지 때문에 시간이 오래 걸리고 저장 공간을 많이 사용합니다.

Dockerfile이나 버전 파일을 변경한 뒤 로컬 소스를 갱신할 때:

```bash
make cicd-install
```

## GitOps Registration

저장소를 원격 Git에 올린 뒤 Argo CD Application을 등록합니다.

```bash
make deploy-gitops
```

Argo CD는 `charts/layered-model/values-local.yaml`의 새 이미지 태그를 감지하고 자동 동기화합니다.

원격 Git 없이 로컬 클러스터에서 Helm Application을 등록할 때는 내부 Helm 저장소를 사용합니다.

```bash
make argocd-install-local-helm
```

이 명령은 `charts/layered-model`을 패키징하고 `argocd` namespace의 내부 HTTP 저장소에 올린 뒤 `layered-model` Application을 생성합니다. 차트나 values를 바꾼 뒤에는 같은 명령을 다시 실행해 패키지를 갱신합니다.

## Local Harbor

클러스터 내부에서는 호스트의 Harbor를 `host.docker.internal:8080`으로 접근합니다. BuildKit은 이 로컬 HTTP registry를 허용하도록 설정되어 있습니다. KServe용 `harbor-pull` secret과 빌드용 `harbor-docker-config` secret은 `make cicd-install`이 생성합니다.
