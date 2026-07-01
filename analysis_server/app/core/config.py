from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "AI-PMS Unified Analysis & Collection Server"

    # ── 서버 바인딩 ──────────────────────────────────────────────
    aipms_analysis_bind_host: str = "127.0.0.1"
    aipms_analysis_port: int = 8200
    aipms_analysis_allow_public_bind: int = 0

    # ── DB (Platform API 와 같은 PostgreSQL) ─────────────────────
    database_url: str = "postgresql://aipms:aipms@localhost:5432/aipms"

    # ── Ollama LLM ───────────────────────────────────────────────
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "qwen3:4b"
    ollama_fallback_models: str = "qwen2.5:3b,qwen2.5:7b,qwen2:7b"
    default_context_limit: int = 8192
    ollama_timeout_seconds: int = 180

    # ── Whisper STT ──────────────────────────────────────────────
    whisper_cpp_bin: str = "/opt/homebrew/bin/whisper-cli"
    ffmpeg_bin: str = "/opt/homebrew/bin/ffmpeg"
    whisper_model_path: str = ""
    whisper_timeout_seconds: int = 300

    # ── 오디오 파일 저장 ─────────────────────────────────────────
    audio_storage_dir: str = "audio_storage"

    # ── Platform API 콜백 ─────────────────────────────────────────
    platform_api_url: str = "http://localhost:8000"
    platform_callback_secret: str = "dev-platform-callback-secret"
    platform_callback_secret_id: str = "default"
    platform_callback_enabled: bool = True
    platform_callback_timeout_seconds: int = 30
    platform_callback_max_attempts: int = 5
    platform_callback_base_backoff_seconds: int = 60
    platform_callback_max_backoff_seconds: int = 3600
    platform_callback_retry_batch_size: int = 20
    collection_internal_api_secret: str = ""

    # ── 내부 워커 ────────────────────────────────────────────────
    worker_id: str = "integrated-worker-001"
    worker_loop_enabled: bool = True
    worker_loop_interval_seconds: int = 10
    default_lease_seconds: int = 600
    max_job_attempts: int = 3

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
