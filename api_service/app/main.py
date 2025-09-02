# api_service/app/main.py

import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from contextlib import asynccontextmanager
from loguru import logger
from app.routes import api
from app.data.configs.logging_configs import setup_logging
from app.data.database.core_db import connect as db_connect, disconnect as db_disconnect
from app.services.websocket_manager import websocket_manager
from app.data.configs.app_settings import settings
from app.services.event_poller import poll_for_events, stop_poller

background_tasks = []

@asynccontextmanager
async def lifespan(app: FastAPI):
    global background_tasks
    setup_logging()
    logger.info("Starting FlowLens API Service with polling-based architecture...")
    await db_connect()

    # Start only the polling service (removed trigger logic completely)
    logger.info("Starting database poller with 2-second interval...")
    poller_task = asyncio.create_task(poll_for_events())
    background_tasks.append(poller_task)

    logger.success("FlowLens API Service startup complete! Polling architecture ready.")
    yield
    
    logger.info("Shutting down FlowLens API Service...")
    
    # Signal poller to stop
    stop_poller()
        
    # Gracefully cancel all running tasks
    for task in background_tasks:
        task.cancel()
    
    try:
        if background_tasks:
            await asyncio.gather(*background_tasks, return_exceptions=True)
            logger.warning("All background tasks cancelled.")
    except asyncio.CancelledError:
        pass
    
    await db_disconnect()
    logger.success("FlowLens API Service shutdown complete!")


app = FastAPI(
    lifespan=lifespan,
    title="FlowLens API Service",
    description="AI-Powered DevOps Workflow Visualizer - Repository-Centric API",
    version="2.0.0"
)

app.include_router(api.router)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint for real-time PR state updates.
    Sends minimal updates with only repo_id, pr_number, and state for Flutter integration.
    """
    await websocket_manager.connect(websocket)
    try:
        while True:
            # Keep the connection alive
            # Client doesn't need to send messages, just receives updates
            await websocket.receive_text()
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket)

@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "online", 
        "service": "flowlens-api-service",
        "version": "2.0.0",
        "architecture": "repository-centric",
        "processing_mode": "POLL"
    }

@app.get("/health")
async def health_check():
    """Detailed health check with database connectivity."""
    try:
        from app.data.database.core_db import get_db
        db = get_db()
        # Simple connectivity test
        await db.fetch_one("SELECT 1 as test")
        return {
            "status": "healthy",
            "database": "connected",
            "processing_mode": "POLL",
            "version": "2.0.0"
        }
    except Exception as e:
        logger.error("Health check failed", exception=e)
        return {
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e),
            "version": "2.0.0"
        }