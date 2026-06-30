from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Mac mini Analysis Server"
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "qwen3:4b"
    default_context_limit: int = 8192
    whisper_cpp_bin: str = "/opt/homebrew/bin/whisper-cli"
    ffmpeg_bin: str = "/opt/homebrew/bin/ffmpeg"
    whisper_model_path: str = ""
    whisper_timeout_seconds: int = 300
    collection_api_url: str = "http://localhost:8200"
    worker_id: str = "mac-mini-worker-001"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
