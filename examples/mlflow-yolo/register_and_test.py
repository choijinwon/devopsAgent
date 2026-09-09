import json
import os
from pathlib import Path
from typing import Any

import mlflow
import pandas as pd
from mlflow.models import infer_signature
from PIL import Image
from ultralytics import YOLO


TRACKING_URI = os.getenv(
    "MLFLOW_TRACKING_URI", "http://mlflow-mlflow.mlflow.svc.cluster.local:5000"
)
EXPERIMENT_NAME = os.getenv("MLFLOW_EXPERIMENT_NAME", "yolo-registration")
REGISTERED_MODEL_NAME = os.getenv("MLFLOW_REGISTERED_MODEL_NAME", "yolo11n-detector")
MODEL_SOURCE = os.getenv("YOLO_MODEL", "yolo11n.pt")
SAMPLE_IMAGE = os.getenv("YOLO_SAMPLE_IMAGE", "https://ultralytics.com/images/bus.jpg")
CONFIDENCE = float(os.getenv("YOLO_CONFIDENCE", "0.25"))
WORK_DIR = Path(os.getenv("YOLO_WORK_DIR", "/work"))


def summarize(result: Any, source: str) -> dict[str, Any]:
    detections = []
    if result.boxes is not None:
        for xyxy, confidence, class_id in zip(
            result.boxes.xyxy.cpu().tolist(),
            result.boxes.conf.cpu().tolist(),
            result.boxes.cls.cpu().tolist(),
        ):
            class_index = int(class_id)
            detections.append(
                {
                    "class_id": class_index,
                    "class_name": result.names[class_index],
                    "confidence": round(float(confidence), 6),
                    "xyxy": [round(float(value), 2) for value in xyxy],
                }
            )
    return {
        "image": source,
        "detection_count": len(detections),
        "top_class": detections[0]["class_name"] if detections else "",
        "detections_json": json.dumps(detections, ensure_ascii=True),
    }


class YoloDetector(mlflow.pyfunc.PythonModel):
    def load_context(self, context: mlflow.pyfunc.PythonModelContext) -> None:
        self.model = YOLO(context.artifacts["weights"])

    def predict(
        self,
        context: mlflow.pyfunc.PythonModelContext,
        model_input: pd.DataFrame,
        params: dict[str, Any] | None = None,
    ) -> pd.DataFrame:
        confidence = float((params or {}).get("confidence", CONFIDENCE))
        rows = []
        for source in model_input["image"].astype(str).tolist():
            result = self.model.predict(
                source=source,
                conf=confidence,
                device="cpu",
                verbose=False,
            )[0]
            rows.append(summarize(result, source))
        return pd.DataFrame(rows)


def model_version(client: mlflow.MlflowClient, model_info: Any) -> str:
    version = getattr(model_info, "registered_model_version", None)
    if version:
        return str(version)
    versions = client.search_model_versions(f"name='{REGISTERED_MODEL_NAME}'")
    return str(max(int(item.version) for item in versions))


def main() -> None:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    os.chdir(WORK_DIR)
    mlflow.set_tracking_uri(TRACKING_URI)
    mlflow.set_experiment(EXPERIMENT_NAME)

    native_model = YOLO(MODEL_SOURCE)
    native_result = native_model.predict(
        source=SAMPLE_IMAGE,
        conf=CONFIDENCE,
        device="cpu",
        verbose=False,
    )[0]
    native_summary = summarize(native_result, SAMPLE_IMAGE)
    if native_summary["detection_count"] < 1:
        raise RuntimeError("YOLO smoke image produced no detections")

    annotated_path = WORK_DIR / "bus-detections.jpg"
    Image.fromarray(native_result.plot()[..., ::-1]).save(annotated_path)
    input_example = pd.DataFrame([{"image": SAMPLE_IMAGE}])
    output_example = pd.DataFrame([native_summary])
    signature = infer_signature(
        input_example,
        output_example,
        params={"confidence": CONFIDENCE},
    )
    weights_path = Path(native_model.ckpt_path).resolve()

    with mlflow.start_run(run_name="yolo11n-register-and-test") as run:
        mlflow.log_params(
            {
                "model_source": MODEL_SOURCE,
                "sample_image": SAMPLE_IMAGE,
                "confidence": CONFIDENCE,
                "device": "cpu",
            }
        )
        mlflow.log_metric("native_detection_count", native_summary["detection_count"])
        mlflow.log_artifact(str(annotated_path), artifact_path="predictions")
        mlflow.log_dict(native_summary, "predictions/native-result.json")

        model_info = mlflow.pyfunc.log_model(
            name="model",
            python_model=YoloDetector(),
            artifacts={"weights": str(weights_path)},
            input_example=input_example,
            signature=signature,
            pip_requirements=[
                f"mlflow=={mlflow.__version__}",
                "ultralytics==8.4.144",
                "opencv-python-headless<5",
                "pandas<3",
            ],
            registered_model_name=REGISTERED_MODEL_NAME,
            await_registration_for=300,
        )

        client = mlflow.MlflowClient()
        version = model_version(client, model_info)
        client.set_registered_model_alias(REGISTERED_MODEL_NAME, "champion", version)
        client.set_model_version_tag(
            REGISTERED_MODEL_NAME, version, "validation_status", "PASSED"
        )

        registry_uri = f"models:/{REGISTERED_MODEL_NAME}@champion"
        loaded_model = mlflow.pyfunc.load_model(registry_uri)
        registry_result = loaded_model.predict(
            input_example, params={"confidence": CONFIDENCE}
        )
        detection_count = int(registry_result.iloc[0]["detection_count"])
        if detection_count < 1:
            raise RuntimeError("Registry-loaded YOLO model produced no detections")

        mlflow.log_metric("registry_detection_count", detection_count)
        mlflow.log_dict(
            registry_result.to_dict(orient="records")[0],
            "predictions/registry-result.json",
        )
        print(
            json.dumps(
                {
                    "status": "PASSED",
                    "tracking_uri": TRACKING_URI,
                    "experiment": EXPERIMENT_NAME,
                    "run_id": run.info.run_id,
                    "registered_model": REGISTERED_MODEL_NAME,
                    "version": version,
                    "alias": "champion",
                    "detection_count": detection_count,
                    "top_class": registry_result.iloc[0]["top_class"],
                },
                ensure_ascii=True,
            )
        )


if __name__ == "__main__":
    main()
