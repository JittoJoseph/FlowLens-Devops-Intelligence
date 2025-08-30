from fastapi import FastAPI
from contextlib import asynccontextmanager
from loguru import logger
from app.data.configs.app_settings import settings
from app.routes.api import api
from app.data.configs.logging_configs import setup_logging
from app.data.database.core_db import connect as db_connect, disconnect as db_disconnect


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Manages the application's startup and shutdown events.
    """    
    # --- Runs on startup ---
    setup_logging()

    logger.info("Starting up application... !")
    await db_connect()

    logger.success("Application startup complete !")
    
    yield  # The application is now running
    
    # --- Runs on shutdown ---
    logger.info("Shutting down application... !")
    await db_disconnect()
    logger.success("Application shutdown complete !")


app = FastAPI(
    lifespan=lifespan,
    title="CodeLens API Service",
    description="The core backend service that connects everything securely",
    version="1.0.0"
)

# Enable debug mode based on settings
app.debug = settings.DEBUG

# Include routers
app.include_router(api.router)


@app.get("/")
async def root():
    """Health check endpoint"""
    return {"status": "online", "service": "codelens-api-service"}