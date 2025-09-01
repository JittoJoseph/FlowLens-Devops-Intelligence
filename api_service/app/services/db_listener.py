# api_service/app/services/db_listener.py

import asyncio
from loguru import logger
from app.data.database import core_db
from app.services.event_processor import process_event_by_id

# --- A simple flag for graceful shutdown ---
_running = True

def stop_listener():
    global _running
    _running = False
    logger.info("Stop signal received for DB listener.")

async def listen_for_db_notifications():
    """
    Listens for DB notifications using a dedicated, resilient connection.
    This is the primary, real-time event processing trigger.
    """
    logger.info("Starting database notification listener...")
    db = core_db.get_listener_db()

    # The outer loop handles reconnecting if the connection is ever lost.
    while _running:
        try:
            # We use `iterate` which is designed for long-lived operations like LISTEN.
            # It will yield notifications as they arrive.
            async for notification in db.iterate("LISTEN new_event"):
                if not _running:
                    break
                
                event_id = notification['payload']
                logger.success(f"NOTIFICATION RECEIVED: New event ID is {event_id}")

                # --- The CORE LOGIC ---
                # 1. Process the event immediately.
                try:
                    await process_event_by_id(event_id)
                    # 2. Mark it as processed.
                    await db_helpers.update(
                        "raw_events", data={"processed": True}, where={"id": event_id}
                    )
                    logger.info(f"Successfully processed and marked event {event_id}.")
                except Exception as e:
                    # If processing fails, we log it. The event remains unprocessed
                    # in the DB and can be picked up by a fallback mechanism or manual check.
                    logger.error(f"Failed to process event {event_id} from notification. It remains unprocessed. Error: {e}")

        except asyncio.CancelledError:
            logger.warning("DB listener task was cancelled.")
            break
        except Exception as e:
            logger.error(f"DB listener connection failed: {e}. Reconnecting in 5 seconds...")
            await asyncio.sleep(5) # Wait before trying to reconnect
    
    logger.info("Database notification listener has shut down.")