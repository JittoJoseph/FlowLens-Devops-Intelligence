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
from app.services.db_listener import listen_for_db_notifications, stop_listener
from app.services.event_poller import poll_for_events, stop_poller

background_tasks = []

@asynccontextmanager
async def lifespan(app: FastAPI):
    global background_tasks
    setup_logging()
    logger.info("Starting up application...")
    await db_connect()

    # --- Start background services based on config ---
    if settings.EVENT_PROCESSING_MODE == "LISTEN":
        logger.info("EVENT_PROCESSING_MODE is 'LISTEN'. Starting listener with fallback poller.")
        # Fast path: Real-time listener
        listener_task = asyncio.create_task(listen_for_db_notifications())
        # Safety net: Slow poller to catch any missed events
        fallback_poller_task = asyncio.create_task(poll_for_events(is_fallback=True))
        background_tasks.extend([listener_task, fallback_poller_task])
    
    elif settings.EVENT_PROCESSING_MODE == "POLL":
        logger.warning("EVENT_PROCESSING_MODE is 'POLL'. Running in polling-only mode.")
        # Primary poller for environments where LISTEN/NOTIFY is unreliable
        poller_task = asyncio.create_task(poll_for_events())
        background_tasks.append(poller_task)

    logger.success("Application startup complete!")
    yield
    
    logger.info("Shutting down application...")
    
    # --- Signal all services to stop ---
    if settings.EVENT_PROCESSING_MODE == "LISTEN":
        stop_listener()
        stop_poller() # Also stop the fallback poller
    elif settings.EVENT_PROCESSING_MODE == "POLL":
        stop_poller()
        
    # --- Gracefully cancel all running tasks ---
    for task in background_tasks:
        task.cancel()
    
    try:
        if background_tasks:
            await asyncio.gather(*background_tasks, return_exceptions=True)
            logger.warning("All background tasks cancelled.")
    except asyncio.CancelledError:
        pass
    
    await db_disconnect()
    logger.success("Application shutdown complete!")


app = FastAPI(
    lifespan=lifespan,
    title="FlowLens API Service",
    version="1.0.0"
)

app.include_router(api.router)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket_manager.connect(websocket)
    try:
        while True:
            # We can set a timeout to periodically check connection state if needed
            # For now, just waiting is fine.
            await websocket.receive_text()
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket)

@app.get("/")
async def root():
    return {"status": "online", "service": "flowlens-api-service"}