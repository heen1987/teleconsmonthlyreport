from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "AI-PMS Collection & Analysis Service"
    database_url: str = "postgresql://ai_pms:ai_pms@localhost:5432/ai_pms"
    default_lease_seconds: int = 300
    max_job_attempts: int = 3
    audio_storage_dir: str = "storage/audio"
    platform_api_url: str = "http://localhost:8000"
    platform_callback_enabled: bool = True
    platform_callback_timeout_seconds: int = 10
    platform_callback_secret_id: str = "dev-v1"
    platform_callback_secret: str = "dev-collection-callback-secret"
    platform_callback_max_attempts: int = 5
    platform_callback_base_backoff_seconds: int = 30
    platform_callback_max_backoff_seconds: int = 1800
    platform_callback_retry_loop_enabled: bool = True
    platform_callback_retry_interval_seconds: int = 30
    platform_callback_retry_batch_size: int = 20
    collection_internal_api_secret: str = ""

    # ── 내부 워커 설정 ────────────────────────────────────────────────────────
    worker_id: str = "integrated-worker-001"
    worker_loop_enabled: bool = True
    worker_loop_interval_seconds: int = 10

    # ── Ollama LLM 설정 ───────────────────────────────────────────────────────
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "qwen3:4b"
    ollama_fallback_models: str = "qwen2.5:3b,qwen2.5:7b,qwen2:7b"
    default_context_limit: int = 8192
    ollama_timeout_seconds: int = 180

    # ── Whisper STT 설정 ──────────────────────────────────────────────────────
    whisper_cpp_bin: str = "/opt/homebrew/bin/whisper-cli"
    ffmpeg_bin: str = "/opt/homebrew/bin/ffmpeg"
    whisper_model_path: str = ""
    whisper_timeout_seconds: int = 300

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
