# api_service/app/data/configs/app_settings.py

from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Literal, Optional

class AppSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8', extra='ignore')

    # Gunicorn Settings
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 1
    WORKER_CONNECTIONS: int = 1000
    GUNICORN_TIMEOUT: int = 120
    KEEP_ALIVE: int = 5
    GRACEFUL_TIMEOUT: int = 120

    # Database Main
    DATABASE_URL: str
    POOL_MIN_SIZE: int = 2
    POOL_MAX_SIZE: int = 10
    POOL_ACQUIRE_TIMEOUT: int = 30

    # Services
    GEMINI_API_KEY: str
    GEMINI_AI_MODEL: str = "gemini-2.5-flash"
    AI_TEMP: float = 0.5
    AI_MAX_TOKEN: int = 1024

settings = AppSettings()