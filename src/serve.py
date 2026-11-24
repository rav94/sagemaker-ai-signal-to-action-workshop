"""Serve the fitted Phase 1 pipeline using SageMaker's HTTP contract."""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path

import joblib


MAX_REQUEST_BYTES = 16_384
MAX_MESSAGE_CHARS = 4_000


def classify(model, model_version, payload):
    message = payload.get("message") if isinstance(payload, dict) else None
    if not isinstance(message, str) or not message.strip():
        raise ValueError("message must be a non-empty string")
    if len(message) > MAX_MESSAGE_CHARS:
        raise ValueError(f"message must be at most {MAX_MESSAGE_CHARS} characters")

    probabilities = model.predict_proba([message])[0]
    best = int(probabilities.argmax())
    return {
        "category": str(model.classes_[best]),
        "score": float(probabilities[best]),
        "modelVersion": model_version,
    }


class InferenceHandler(BaseHTTPRequestHandler):
    def respond(self, status, result):
        body = json.dumps(result).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/ping":
            self.respond(200, {"status": "ok"})
        else:
            self.respond(404, {"error": "unknown route"})

    def do_POST(self):
        if self.path != "/invocations":
            self.respond(404, {"error": "unknown route"})
            return
        if self.headers.get_content_type() != "application/json":
            self.respond(415, {"error": "Content-Type must be application/json"})
            return

        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= MAX_REQUEST_BYTES:
                raise ValueError
        except ValueError:
            self.respond(400, {"error": "invalid JSON body length"})
            return

        self.connection.settimeout(5)
        try:
            payload = json.loads(self.rfile.read(size))
        except TimeoutError:
            self.respond(408, {"error": "request body timed out"})
            return
        except (ValueError, RecursionError):
            self.respond(400, {"error": "body must be valid JSON"})
            return
        try:
            result = classify(self.server.model, self.server.model_version, payload)
        except ValueError as error:
            self.respond(400, {"error": str(error)})
            return
        self.respond(200, result)

    def log_request(self, code="-", size="-"):
        print(json.dumps({"status": code, "method": self.command}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["serve"])
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", default=8080, type=int)
    parser.add_argument(
        "--model-dir", type=Path, default=Path(os.getenv("MODEL_DIR", "/opt/ml/model"))
    )
    args = parser.parse_args()

    # SageMaker unpacks the trusted, access-controlled artifact before startup.
    model = joblib.load(args.model_dir / "complaint_classifier.joblib")
    model_version = (args.model_dir / "model-version.txt").read_text().strip()
    if not model_version:
        raise ValueError("model-version.txt must contain a version")
    model.predict_proba(["startup probe"])
    with ThreadingHTTPServer((args.bind, args.port), InferenceHandler) as server:
        server.model = model
        server.model_version = model_version
        server.serve_forever()


if __name__ == "__main__":
    main()
