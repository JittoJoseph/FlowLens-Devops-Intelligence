# api_service/app/services/db_listener.py

import asyncio
from loguru import logger
from app.data.database import core_db, db_helpers
from app.services.event_processor import process_event_by_id

_running = True

def stop_listener():
    global _running
    _running = False
    logger.info("Stop signal received for DB listener.")

async def listen_for_db_notifications():
    """Listens for DB notifications using a dedicated, resilient connection."""
    logger.info("Starting database notification listener...")
    db = core_db.get_listener_db()

    while _running:
        try:
            # The 'databases' library requires manual connection handling for listeners
            async with db.connection() as connection:
                logger.success("DB Listener successfully connected. Listening for 'new_event' notifications.")
                await connection.execute("LISTEN new_event")
                
                while _running:
                    # Wait for a notification on the connection
                    notification = await connection.raw_connection.poll()
                    if notification is None or not _running:
                        await asyncio.sleep(1) # prevent tight loop if poll times out
                        continue

                    event_id = notification.payload
                    logger.success(f"NOTIFICATION RECEIVED: Processing event ID {event_id}")

                    # --- THE CORE RESILIENT LOGIC (same as poller) ---
                    try:
                        await process_event_by_id(event_id)
                        await db_helpers.update(
                            "raw_events", data={"processed": True}, where={"id": event_id}
                        )
                        logger.info(f"[Listener] Successfully processed and marked event {event_id}.")
                    except Exception as e:
                        logger.error(f"[Listener] Failed to process event {event_id} from notification. It remains unprocessed for the fallback poller. Error: {e}")
        
        except asyncio.CancelledError:
            logger.warning("DB listener task was cancelled.")
            break
        except Exception as e:
            logger.error(f"DB listener connection failed: {e}. Reconnecting in 5 seconds...")
            await asyncio.sleep(5)
    
    logger.info("Database notification listener has shut down.")