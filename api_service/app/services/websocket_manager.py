# api_service/app/services/websocket_manager.py

import json
from typing import List
from uuid import UUID
from fastapi import WebSocket
from loguru import logger
from app.data.database import db_helpers


class WebSocketManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"New WebSocket connection. Total connections: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        logger.info(f"WebSocket disconnected. Total connections: {len(self.active_connections)}")

    async def broadcast_json(self, data: dict):
        """Broadcast JSON data to all connected clients."""
        if not self.active_connections:
            return
        
        # Convert UUID objects to strings for JSON serialization
        serializable_data = self._serialize_for_json(data)
        message = json.dumps(serializable_data)
        disconnected = []
        
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception as e:
                logger.warning(f"Failed to send message to client: {e}")
                disconnected.append(connection)
        
        # Remove disconnected clients
        for connection in disconnected:
            self.disconnect(connection)
        
        if disconnected:
            logger.info(f"Cleaned up {len(disconnected)} disconnected clients")

    def _serialize_for_json(self, data):
        """Convert UUID objects and other non-serializable types to strings."""
        if isinstance(data, dict):
            return {key: self._serialize_for_json(value) for key, value in data.items()}
        elif isinstance(data, list):
            return [self._serialize_for_json(item) for item in data]
        elif isinstance(data, UUID):
            return str(data)
        else:
            return data

    async def broadcast_pr_state_update(self, repo_id, pr_number: int):
        """
        Broadcast only PR state updates with minimal data for Flutter real-time updates.
        Sends only: repo_id, pr_number, and current state.
        """
        try:
            # Convert repo_id to string if it's a UUID
            repo_id_str = str(repo_id) if isinstance(repo_id, UUID) else repo_id
            
            # Get current PR state
            pr_data = await db_helpers.select_one(
                "pull_requests",
                where={"repo_id": repo_id, "pr_number": pr_number},
                select_fields="state, merged, is_draft"
            )
            
            if not pr_data:
                logger.warning(f"PR #{pr_number} not found in repository {repo_id_str}")
                return
            
            # Simple state message with only essential data
            state_message = {
                "repo_id": repo_id_str,
                "pr_number": pr_number,
                "state": pr_data["state"]
            }
            
            await self.broadcast_json(state_message)
            logger.success(f"Broadcasted state update for PR #{pr_number} in {repo_id_str}: {pr_data['state']}")
            
        except Exception as e:
            logger.error(f"Failed to broadcast PR state update for #{pr_number} in {repo_id}: {e}")


websocket_manager = WebSocketManager()