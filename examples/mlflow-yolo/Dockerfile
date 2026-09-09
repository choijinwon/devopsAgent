ARG BASE_IMAGE=localhost:8080/library/layered-kserve:u24-cu128-py312-torch210-mlflow3152-kserve0190-c269b4c78ded-g6
FROM ${BASE_IMAGE}

USER root
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install 'polars[rtcompat]==1.44.1' \
    && pip install \
      'opencv-python-headless<5' \
      'nvidia-ml-py>=12' \
      'ultralytics-platform>=0.1.32' \
      'ultralytics-thop>=2.1.6' \
    && pip install --no-deps 'ultralytics==8.4.144'

COPY examples/mlflow-yolo/serve.py /opt/model-server/yolo_mlflow_server.py
RUN chown 10001:10001 /opt/model-server/yolo_mlflow_server.py

USER 10001:10001
CMD ["python", "/opt/model-server/yolo_mlflow_server.py"]
