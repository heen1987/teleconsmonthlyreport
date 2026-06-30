from fastapi import FastAPI

from app.core.config import settings
from app.routers import analyze, stt
from app.schemas import AnalysisHealth

app = FastAPI(title=settings.app_name)

app.include_router(analyze.router)
app.include_router(stt.router)


@app.get("/health", response_model=AnalysisHealth)
def health():
    return AnalysisHealth(
        status="ok",
        app=settings.app_name,
        model=settings.ollama_model,
    )
