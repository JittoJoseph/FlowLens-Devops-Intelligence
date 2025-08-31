# api_service/app/services/db_listener.py

import asyncio
from loguru import logger
from asyncpg.exceptions import ConnectionDoesNotExistError
from app.data.database import core_db
from app.services.event_processor import process_event_by_id

# --- The asyncio.Event is the key to a truly idle, responsive listener ---
stop_event = asyncio.Event()

def _notification_handler(connection, pid, channel, payload):
    """Callback function that is executed when a notification is received."""
    logger.success(f"NOTIFICATION RECEIVED on channel '{channel}': New event ID is {payload}")
    asyncio.create_task(process_event_by_id(payload))

async def listen_for_db_notifications():
    """Listens for DB notifications using a dedicated, resilient connection."""
    logger.info("Starting database notification listener...")
    
    while not stop_event.is_set():
        connection = None
        try:
            connection = await core_db.create_dedicated_connection()
            await connection.add_listener('new_event', _notification_handler)
            logger.success("Successfully listening for 'new_event' notifications.")
            
            # --- THE FIX ---
            # await stop_event.wait() will pause this function indefinitely
            # until stop_event.set() is called during shutdown.
            # This is the most efficient and correct way to wait.
            await stop_event.wait()

        except asyncio.CancelledError:
            logger.warning("Listener task was cancelled.")
            break
        except Exception as e:
            logger.error(f"DB listener encountered an error: {e}. Reconnecting in 5 seconds...")
        
        if not stop_event.is_set():
            await asyncio.sleep(5)