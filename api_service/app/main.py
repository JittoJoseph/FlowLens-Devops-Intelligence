# api_service/app/main.py

import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from contextlib import asynccontextmanager
from loguru import logger
from app.routes import api
from app.data.configs.logging_configs import setup_logging
from app.data.database.core_db import connect as db_connect, disconnect as db_disconnect
from app.services.websocket_manager import websocket_manager
from app.services.event_poller import poll_for_events, stop_poller

poller_task = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global poller_task
    setup_logging()
    logger.info("Starting up application...")
    await db_connect()

    # --- Start the new poller task ---
    poller_task = asyncio.create_task(poll_for_events())
    logger.info("Background event poller started.")

    logger.success("Application startup complete!")
    yield
    
    logger.info("Shutting down application...")
    if poller_task:
        # --- Signal the new poller to stop ---
        stop_poller()
        poller_task.cancel()
        try:
            await poller_task
        except asyncio.CancelledError:
            logger.warning("Event poller task cancelled successfully.")
    
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
            await websocket.receive_text() # Keep connection alive
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket)

@app.get("/")
async def root():
    return {"status": "online", "service": "flowlens-api-service"}