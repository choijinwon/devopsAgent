import json
import os
from typing import Any

import kserve
import mlflow
import pandas as pd


MODEL_NAME = os.getenv("MODEL_NAME", "yolo11n-detector")
MODEL_URI = os.getenv("MLFLOW_MODEL_URI", f"models:/{MODEL_NAME}@champion")
TRACKING_URI = os.getenv(
    "MLFLOW_TRACKING_URI", "http://mlflow-mlflow.mlflow.svc.cluster.local:5000"
)


class YoloMLflowModel(kserve.Model):
    def __init__(self, name: str) -> None:
        super().__init__(name)
        self.ready = False
        mlflow.set_tracking_uri(TRACKING_URI)
        self.model = mlflow.pyfunc.load_model(MODEL_URI)
        self.ready = True

    def predict(
        self, payload: Any, headers: dict[str, str] | None = None
    ) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise ValueError("Request body must be a JSON object")

        instances = payload.get("instances")
        if not isinstance(instances, list) or not instances:
            raise ValueError("'instances' must be a non-empty list")

        rows = [
            {"image": item} if isinstance(item, str) else item
            for item in instances
        ]
        if any(not isinstance(item, dict) or "image" not in item for item in rows):
            raise ValueError("Each instance must contain an 'image' URL or path")

        parameters = payload.get("parameters", {})
        result = self.model.predict(pd.DataFrame(rows), params=parameters)
        predictions = result.to_dict(orient="records")
        for prediction in predictions:
            detections_json = prediction.pop("detections_json", "[]")
            prediction["detections"] = json.loads(detections_json)

        return {
            "model_name": self.name,
            "model_uri": MODEL_URI,
            "predictions": predictions,
        }


if __name__ == "__main__":
    model = YoloMLflowModel(MODEL_NAME)
    kserve.ModelServer(http_port=int(os.getenv("HTTP_PORT", "8080"))).start([model])
