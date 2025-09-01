# api_service/app/main.py

import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from contextlib import asynccontextmanager
from loguru import logger
from app.routes import api
from app.data.configs.logging_configs import setup_logging
from app.data.database.core_db import connect as db_connect, disconnect as db_disconnect
from app.services.websocket_manager import websocket_manager
# --- Import the new listener and its stop function ---
from app.services.db_listener import listen_for_db_notifications, stop_listener

# --- This will hold our new listener task ---
listener_task = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global listener_task
    setup_logging()
    logger.info("Starting up application...")
    await db_connect()

    # --- Start the new, efficient DB listener task ---
    listener_task = asyncio.create_task(listen_for_db_notifications())
    logger.info("Background database notification listener started.")

    logger.success("Application startup complete!")
    yield
    
    logger.info("Shutting down application...")
    if listener_task:
        # --- Signal the listener to stop ---
        stop_listener()
        listener_task.cancel()
        try:
            await listener_task
        except asyncio.CancelledError:
            logger.warning("DB listener task cancelled successfully.")
    
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