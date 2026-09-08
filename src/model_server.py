import os
from typing import Any

import kserve
import torch


class LayeredModel(kserve.Model):
    def __init__(self, name: str):
        super().__init__(name)
        self.name = name
        self.ready = True

    def predict(self, payload: Any, headers: dict[str, str] | None = None) -> dict[str, Any]:
        values = payload.get("instances", payload) if isinstance(payload, dict) else payload
        tensor = torch.as_tensor(values, dtype=torch.float32)
        return {
            "predictions": tensor.tolist(),
            "runtime": {
                "torch": torch.__version__,
                "cuda": torch.version.cuda,
                "cuda_available": torch.cuda.is_available(),
                "model": self.name,
            },
        }


if __name__ == "__main__":
    model = LayeredModel(os.getenv("MODEL_NAME", "layered-model"))
    kserve.ModelServer(http_port=int(os.getenv("HTTP_PORT", "8080"))).start([model])
