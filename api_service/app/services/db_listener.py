# api_service/app/services/db_listener.py

import asyncio
from loguru import logger
from app.data.database import core_db, db_helpers
from app.services.event_processor import process_event_by_id

_running = True

def stop_listener():
    """Signals the listener to gracefully shut down."""
    global _running
    _running = False
    logger.info("Stop signal received for DB listener.")

async def listen_for_db_notifications():
    """Listens for DB notifications using a resilient, auto-reconnecting loop."""
    logger.info("Starting database notification listener...")
    db = core_db.get_listener_db()

    # The outer loop handles reconnecting if the connection is ever lost.
    while _running:
        try:
            # --- THE CRITICAL FIX ---
            # `db.connection()` returns a context manager, which must be used
            # with `async with` to correctly acquire and release a connection.
            async with db.connection() as connection:
                
                # Define the asynchronous callback function that asyncpg will execute.
                async def _notification_handler(conn, pid, channel, payload):
                    logger.success(f"NOTIFICATION RECEIVED: Processing event ID {payload}")
                    try:
                        await process_event_by_id(payload)
                        # We use the main connection pool for writes for safety
                        await db_helpers.update(
                            "raw_events", data={"processed": True}, where={"id": payload}
                        )
                        logger.info(f"[Listener] Successfully processed and marked event {payload}.")
                    except Exception as e:
                        logger.error(f"[Listener] Failed to process event {payload} from notification. "
                                     f"It remains unprocessed for the fallback poller. Error: {e}")

                # Add the listener using the native asyncpg method on the raw connection.
                await connection.raw_connection.add_listener('new_event', _notification_handler)
                logger.success("DB Listener successfully connected. Listening for 'new_event' notifications.")

                # Keep the connection alive while the application is running.
                # The listener callback is executed in the background by the event loop.
                while _running:
                    await asyncio.sleep(1)
                
                # If the loop was exited by a shutdown signal, clean up the listener.
                logger.info("Shutdown signal received, removing listener...")
                await connection.raw_connection.remove_listener('new_event', _notification_handler)

        except asyncio.CancelledError:
            logger.warning("DB listener task was cancelled.")
            break  # Exit the main while loop immediately on cancellation

        except Exception as e:
            logger.error(f"DB listener task encountered an error: {e}. Reconnecting in 5 seconds...")
            # The `async with` block ensures the connection is closed on error.
            # The outer loop will now wait before trying to reconnect.

        if _running:
            await asyncio.sleep(5)

    logger.info("Database notification listener has shut down.")