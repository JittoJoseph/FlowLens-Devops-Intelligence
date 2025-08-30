# api_service/app/services/websocket_manager.py

import asyncio
from typing import List, Any
from fastapi import WebSocket
from loguru import logger

class WebSocketManager:
    """Manages active WebSocket connections and broadcasts messages."""
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        """Accepts and stores a new WebSocket connection."""
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"New WebSocket connection: {websocket.client}")

    def disconnect(self, websocket: WebSocket):
        """Removes a WebSocket connection."""
        self.active_connections.remove(websocket)
        logger.info(f"WebSocket connection closed: {websocket.client}")

    async def broadcast_json(self, data: Any):
        """Sends a JSON payload to all connected clients."""
        if not self.active_connections:
            return

        logger.info(f"Broadcasting message to {len(self.active_connections)} clients.")
        
        # Use asyncio.gather for concurrent sending
        results = await asyncio.gather(
            *[conn.send_json(data) for conn in self.active_connections],
            return_exceptions=True
        )

        # Handle clients that may have disconnected unexpectedly
        for result, conn in zip(results, self.active_connections):
            if isinstance(result, Exception):
                logger.warning(f"Failed to send to client {conn.client}: {result}")


# Create a single instance to be used throughout the application
websocket_manager = WebSocketManager()