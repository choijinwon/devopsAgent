# Local Harbor

이 저장소는 로컬 개발용 Harbor를 Docker Compose로 설치합니다.

## Install

```bash
make install-harbor
```

기본값:

| Variable | Default |
| --- | --- |
| `HARBOR_VERSION` | `v2.15.2` |
| `HARBOR_HOSTNAME` | `localhost` |
| `HARBOR_HTTP_PORT` | `8080` |
| `HARBOR_ADMIN_PASSWORD` | `Harbor12345` |
| `HARBOR_DATA_VOLUME` | `data/harbor` |
| `HARBOR_WITH_TRIVY` | `false` |

현재 관리자 비밀번호는 Git에서 제외되는 `local/harbor/admin-password`에 권한 `600`으로 저장합니다. CI/CD 설치 스크립트는 이 파일을 우선 사용해 Harbor Secret을 생성합니다.

## Commands

```bash
make harbor-status
make harbor-up
make harbor-down
```

## Push Base Images

```bash
docker login localhost:8080
PUSH=true make build-base VERSION_SET=u24-cu128-py312-torch210-mlflow3152-kserve0190 LAYER=all
```

Docker가 HTTP registry push를 거부하면 Docker Desktop의 insecure registry에 `localhost:8080`을 추가해야 합니다.
