import logging
import sys
from loguru import logger
from app.data.configs.app_settings import settings


def formatter(record: dict) -> str:
    """
    A custom formatter that creates different log formats and appends extra data.
    """
    # This format is used for both production and debug,
    # as the level of detail is controlled by what we log, not the format itself.
    format_string = (
        "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
        "<level>{level: <8}</level> | "
        "<cyan>{name}:{line}</cyan> - <level>{message}</level>"
    )

    if record["extra"]:
        extra_kv = [f"<cyan>{key}</cyan>=<yellow>{value}</yellow>" for key, value in record["extra"].items()]
        format_string += " | " + " ".join(extra_kv)
    
    return format_string + "\n"

def setup_logging():
    """Configures Loguru for production-ready, environment-aware logging."""
    logger.remove()
    log_level = "DEBUG" if settings.DEBUG else "INFO"

    # --- THIS IS THE CRITICAL CHANGE ---
    # In production, we disable the verbose backtrace and diagnose features.
    # In debug, we enable them for maximum detail.
    show_backtrace = settings.DEBUG
    show_diagnose = settings.DEBUG
    
    # In production, silence the overly verbose logs from third-party libraries.
    if not settings.DEBUG:
        noisy_libraries = [
            "googleapiclient", "google_auth_httplib2", "httpx",
            "urllib3", "oauth2client", "gspread", "httpcore",
        ]
        for lib_name in noisy_libraries:
            logging.getLogger(lib_name).setLevel(logging.WARNING)

    # Add the sink with our smart, environment-aware settings.
    logger.add(
        sys.stderr, # Use stderr to separate from Gunicorn's access logs
        level=log_level,
        format=formatter,
        colorize=True,
        enqueue=True, # For performance
        backtrace=show_backtrace, # <-- Controlled by settings.DEBUG
        diagnose=show_diagnose   # <-- Controlled by settings.DEBUG
    )

    logger.info("Loguru logging configured", mode='DEBUG' if settings.DEBUG else 'PRODUCTION')