CLUSTER ?= dev
LAYER ?= all
VERSION_SET ?= u24-cu128-py312-torch210-mlflow3152-kserve0190
IMAGE_REPO ?= localhost:8080/library/layered-kserve
HARBOR_VERSION ?= v2.15.2
MLFLOW_CHART_VERSION ?= 0.1.0
MLFLOW_LOCAL_PORT ?= 5001
ARGO_WORKFLOWS_LOCAL_PORT ?= 2746

.PHONY: build-base build-base-all list-version-sets helm-template helm-install-model helm-uninstall-model argocd-install-local-helm mlflow-install mlflow-upgrade mlflow-uninstall mlflow-status mlflow-port-forward argo-workflows-port-forward install-harbor harbor-up harbor-down harbor-status cicd-install cicd-enable-kind-buildkit cicd-configure-kind-registry cicd-run cicd-smoke cicd-status deploy deploy-gitops destroy destroy-gitops validate status

build-base:
	IMAGE_REPO=$(IMAGE_REPO) VERSION_SET=$(VERSION_SET) LAYER=$(LAYER) scripts/build-version-set.sh $(VERSION_SET)

build-base-all:
	IMAGE_REPO=$(IMAGE_REPO) LAYER=$(LAYER) scripts/build-all-version-sets.sh

list-version-sets:
	scripts/list-version-sets.sh

helm-template:
	helm template layered-model charts/layered-model -f charts/layered-model/values-local.yaml

helm-install-model:
	helm upgrade --install layered-model charts/layered-model -f charts/layered-model/values-local.yaml --namespace model-serving --create-namespace

helm-uninstall-model:
	helm uninstall layered-model --namespace model-serving

argocd-install-local-helm:
	scripts/install-local-argocd-helm.sh

mlflow-install:
	helm upgrade --install mlflow oci://ghcr.io/mlflow/charts/mlflow --version $(MLFLOW_CHART_VERSION) --namespace mlflow --create-namespace -f helm-values/mlflow-local.yaml

mlflow-upgrade:
	helm upgrade mlflow oci://ghcr.io/mlflow/charts/mlflow --version $(MLFLOW_CHART_VERSION) --namespace mlflow -f helm-values/mlflow-local.yaml

mlflow-uninstall:
	helm uninstall mlflow --namespace mlflow

mlflow-status:
	helm status mlflow --namespace mlflow
	kubectl get pods,svc,pvc -n mlflow

mlflow-port-forward:
	kubectl port-forward -n mlflow svc/mlflow-mlflow $(MLFLOW_LOCAL_PORT):5000 --address 127.0.0.1

argo-workflows-port-forward:
	ARGO_WORKFLOWS_LOCAL_PORT=$(ARGO_WORKFLOWS_LOCAL_PORT) scripts/port-forward-argo-workflows.sh

install-harbor:
	scripts/install-local-harbor.sh

harbor-up:
	docker compose -f local/harbor/$(HARBOR_VERSION)/harbor/docker-compose.yml up -d

harbor-down:
	docker compose -f local/harbor/$(HARBOR_VERSION)/harbor/docker-compose.yml down

harbor-status:
	docker compose -f local/harbor/$(HARBOR_VERSION)/harbor/docker-compose.yml ps

cicd-install:
	scripts/install-cicd.sh

cicd-enable-kind-buildkit:
	scripts/enable-kind-buildkit.sh

cicd-configure-kind-registry:
	scripts/configure-kind-harbor.sh

cicd-run:
	scripts/run-cicd.sh

cicd-smoke:
	scripts/run-local-cicd-smoke.sh

cicd-status:
	kubectl -n argo get workflowtemplate layered-model-cicd
	kubectl -n argo get workflows --sort-by=.metadata.creationTimestamp
	kubectl -n buildkit get deployment,pod,service
	kubectl -n argocd get applications.argoproj.io

deploy:
	CLUSTER=$(CLUSTER) scripts/deploy-layer.sh $(LAYER)

deploy-gitops:
	CLUSTER=$(CLUSTER) scripts/deploy-layer.sh gitops

destroy:
	CLUSTER=$(CLUSTER) scripts/destroy-layer.sh $(LAYER)

destroy-gitops:
	CLUSTER=$(CLUSTER) scripts/destroy-layer.sh gitops

validate:
	scripts/validate.sh $(CLUSTER)

status:
	kubectl get ns argocd argo buildkit kserve model-serving
	kubectl -n argocd get deploy,svc 2>/dev/null || true
	kubectl -n argo get deploy,svc,pod 2>/dev/null || true
	kubectl -n buildkit get deploy,svc,pod 2>/dev/null || true
	kubectl -n kserve get deploy,svc,pod 2>/dev/null || true
	kubectl get clusterservingruntime 2>/dev/null || true
