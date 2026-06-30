from __future__ import annotations

import importlib.util
import json
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def ensure_project_dependencies() -> None:
    try:
        import pydantic  # noqa: F401
    except ModuleNotFoundError:
        project_python = ROOT / "backend" / ".venv" / "bin" / "python"
        if project_python.exists() and Path(sys.executable) != project_python:
            os.execv(str(project_python), [str(project_python), *sys.argv])
        raise


def load_module(module_name: str, path: Path):
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load module from {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def main() -> None:
    ensure_project_dependencies()

    schema_path = ROOT / "contracts" / "analysis_result.schema.json"
    json.loads(schema_path.read_text(encoding="utf-8"))

    sample = {
        "schema_version": "analysis.v1",
        "language": "ko",
        "summary": "회의 요약 초안",
        "transcript_segments": [
            {
                "segment_id": "seg-001",
                "speaker": None,
                "text": "분석 JSON Schema를 먼저 작성하기로 했습니다.",
            }
        ],
        "decisions": [
            {
                "content": "분석 JSON Schema를 공통 계약으로 둔다.",
                "confidence": 0.8,
            }
        ],
        "action_items": [
            {
                "title": "analysis.v1 스키마 작성",
                "target_module": "task",
                "priority": "high",
            }
        ],
        "risks": [
            {
                "title": "API 구현 전 계약이 흔들릴 수 있음",
                "level": "medium",
            }
        ],
        "required_resources": [
            {
                "name": "Mac mini",
                "resource_type": "equipment",
                "quantity": 1,
            }
        ],
        "requires_human_approval": True,
    }

    analysis_schemas = load_module(
        "analysis_server_schemas",
        ROOT / "analysis_server" / "app" / "schemas.py",
    )
    backend_schemas = load_module(
        "backend_schemas",
        ROOT / "backend" / "app" / "schemas.py",
    )

    analysis_schemas.MeetingAnalysisPayload.model_rebuild(_types_namespace=vars(analysis_schemas))
    backend_schemas.MeetingAnalysisResult.model_rebuild(_types_namespace=vars(backend_schemas))
    analysis_schemas.MeetingAnalysisPayload.model_validate(sample)
    backend_schemas.MeetingAnalysisResult.model_validate(sample)

    review_package_path = ROOT / "contracts" / "web_review_package.example.json"
    review_package = json.loads(review_package_path.read_text(encoding="utf-8"))
    backend_schemas.MeetingReviewPackage.model_rebuild(_types_namespace=vars(backend_schemas))
    backend_schemas.MeetingReviewPackage.model_validate(review_package)
    print("analysis.v1 and web review package contract validation passed")


if __name__ == "__main__":
    main()
