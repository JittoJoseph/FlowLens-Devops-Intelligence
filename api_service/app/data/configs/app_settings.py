from pydantic_settings import BaseSettings
from pydantic import Field
from typing import List


# Base settings
class Settings(BaseSettings):

    GEMINI_API_KEY: str

    # === [Database] ===
    DATABASE_URL: str 

    POOL_MIN_SIZE: int = 2      
    POOL_MAX_SIZE: int = 15
    POOL_ACQUIRE_TIMEOUT: float = 10.0

    # === [URL of Core API] ===
    API_SERVICE_URL: str = ""
    INGESTION_SERVICE_URL: str = ""

    # === [Gemini models] ===
    PRIMARY_MODEL: str = "gemini-2.5-flash" # "gemini-2.5-flash-preview-04-17" 
    FALLBACK_MODEL: str = "gemini-1.5-flash"
    
    # === [System prompt paths] ===
    CORE_SYSTEM_PROMPT_PATH: str = "app/data/prompts/get_insight.txt"

    # === [AI] ===
    MODEL_TEMP: float = 0.5
    TOKEN_LIMIT: int = 4096

    # === [Gunicorn server settings] ===
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 1
    WORKER_CONNECTIONS: int = 1000
    GUNICORN_TIMEOUT: int = 360 
    KEEP_ALIVE: int = 15
    GRACEFUL_TIMEOUT: int = 30
    
    LOG_LEVEL: str = "info"

    # === [Dev mode] ===
    DEBUG: bool = False

    class Config:
        env_file = ".env"
        extra = "ignore"
    
settings = Settings()

