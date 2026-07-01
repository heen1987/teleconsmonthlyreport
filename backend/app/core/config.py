from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "AI-PMS Platform API"
    platform_cors_allow_origins: str = (
        "http://localhost:3000,"
        "http://127.0.0.1:3000,"
        "https://juyeoon.github.io"
    )
    platform_cors_allow_origin_regex: str = (
        r"^http://(localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|"
        r"172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+|"
        r"192\.168\.\d+\.\d+)(:\d+)?$"
    )
    database_url: str = "postgresql://ai_pms:ai_pms@localhost:5432/ai_pms"
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "qwen3:4b"
    analysis_server_url: str = "http://localhost:8100"
    analysis_request_timeout_seconds: int = 120
    collection_api_url: str = "http://localhost:8200"
    collection_poll_timeout_seconds: int = 180
    collection_poll_interval_seconds: float = 2.0
    collection_callback_secret_id: str = "dev-v1"
    collection_callback_secret: str = "dev-collection-callback-secret"
    collection_internal_api_secret: str = ""
    collection_callback_previous_secrets: str = ""
    collection_callback_max_age_seconds: int = 300
    access_token_ttl_seconds: int = 28800
    password_reset_token_ttl_seconds: int = 1800
    password_reset_delivery_mode: str = "dev_log"
    email_delivery_mode: str = "dev_log"
    email_from_address: str = "no-reply@aipms.local"
    email_smtp_host: str = ""
    email_smtp_port: int = 587
    email_smtp_username: str = ""
    email_smtp_password: str = ""
    email_smtp_use_tls: bool = True
    email_retry_max_attempts: int = 3
    email_retry_delay_seconds: int = 300
    erp_handoff_delivery_mode: str = "dev_log"
    erp_handoff_endpoint_url: str = ""
    erp_handoff_api_key: str = ""
    erp_handoff_timeout_seconds: int = 15
    erp_handoff_retry_max_attempts: int = 3
    erp_handoff_retry_delay_seconds: int = 300
    android_update_enabled: bool = True
    android_update_package_name: str = "com.aipms"
    android_update_latest_version_code: int = 1
    android_update_latest_version_name: str = "0.1.0"
    android_update_apk_url: str = ""
    android_update_sha256: str = ""
    android_update_mandatory: bool = False
    android_update_release_notes: str = "No update is configured."

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    @property
    def platform_cors_allow_origin_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.platform_cors_allow_origins.split(",")
            if origin.strip()
        ]


settings = Settings()
