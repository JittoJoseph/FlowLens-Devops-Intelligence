import os
import sys
import signal
import subprocess

from loguru import logger
from app.data.configs.app_settings import settings

# A simple logger for this runner script itself.
logger.remove()
logger.add(sys.stderr, format="<yellow>[RUNNER]</yellow> | <level>{message}</level>")

def main():
    """Constructs and runs the Gunicorn command using a simple, direct approach."""
    
    # Use Gunicorn's own flags to format its access logs.
    # This is the most reliable way to get the simple output you want.
    access_log_format = '%(h)s - "%(r)s" %(s)s'
    
    if settings.DEBUG:
        access_log_format = '%(h)s - "%(r)s" %(s)s - %(L)s s - "%(a)s"'
    
    cmd = [
        "gunicorn",
        "app.main:app",
        "-k", "uvicorn.workers.UvicornWorker",
        "-b", f"{settings.HOST}:{settings.PORT}",
        "--workers", str(settings.WORKERS),
        "--worker-connections", str(settings.WORKER_CONNECTIONS),
        "--timeout", str(settings.GUNICORN_TIMEOUT),
        "--keep-alive", str(settings.KEEP_ALIVE),
        "--graceful-timeout", str(settings.GRACEFUL_TIMEOUT),
        
        # --- Direct Gunicorn Logging Configuration ---
        "--access-logfile", "-",  # Send access logs to stdout
        "--error-logfile", "-",   # Send error/system logs to stderr
        "--access-logformat", access_log_format,
    ]

    if settings.DEBUG:
        cmd += ["--reload", "--log-level", "debug"]
        logger.warning("Running in DEBUG mode with auto-reload enabled.")
    else:
        cmd += ["--log-level", "info"]

    logger.info(f"Starting server with command: {' '.join(cmd)}")

    proc = subprocess.Popen(cmd, preexec_fn=os.setsid)

    def shutdown_handler(signum, frame):
        logger.warning(f"Received signal {signum}. Forwarding SIGTERM to Gunicorn...")
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except ProcessLookupError:
            pass # Gunicorn already exited.

    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    try:
        return_code = proc.wait()
        logger.info(f"Gunicorn process exited with code {return_code}.")
        sys.exit(return_code)
    except KeyboardInterrupt:
        logger.warning("Interrupted by user. Shutting down...")

if __name__ == "__main__":
    main()