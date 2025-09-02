# api_service/app/services/db_listener.py

import asyncio
from loguru import logger
from app.data.database import core_db, db_helpers
from app.services.event_processor import process_notification_by_type_and_id

_running = True

def stop_listener():
    """Signals the listener to gracefully shut down."""
    global _running
    _running = False
    logger.info("Stop signal received for DB listener.")


async def listen_for_db_notifications():
    """
    Listens for database notifications from the new trigger system.
    Handles 'pr_event', 'pipeline_event', and 'insight_event' channels.
    """
    logger.info("Starting database notification listener for new trigger system...")
    db = core_db.get_listener_db()

    # The outer loop handles reconnecting if the connection is ever lost.
    while _running:
        try:
            # Use async context manager for connection handling
            async with db.connection() as connection:
                
                # Define notification handlers for each event type
                async def _pr_notification_handler(conn, pid, channel, payload):
                    logger.success(f"PR_EVENT NOTIFICATION: Processing PR record ID {payload}")
                    try:
                        await process_notification_by_type_and_id('pr_event', payload)
                        logger.info(f"[Listener] Successfully processed PR event {payload}.")
                    except Exception as e:
                        logger.error(f"[Listener] Failed to process PR event {payload}. Error: {e}")

                async def _pipeline_notification_handler(conn, pid, channel, payload):
                    logger.success(f"PIPELINE_EVENT NOTIFICATION: Processing pipeline record ID {payload}")
                    try:
                        await process_notification_by_type_and_id('pipeline_event', payload)
                        logger.info(f"[Listener] Successfully processed pipeline event {payload}.")
                    except Exception as e:
                        logger.error(f"[Listener] Failed to process pipeline event {payload}. Error: {e}")

                async def _insight_notification_handler(conn, pid, channel, payload):
                    logger.success(f"INSIGHT_EVENT NOTIFICATION: Processing insight record ID {payload}")
                    try:
                        await process_notification_by_type_and_id('insight_event', payload)
                        logger.info(f"[Listener] Successfully processed insight event {payload}.")
                    except Exception as e:
                        logger.error(f"[Listener] Failed to process insight event {payload}. Error: {e}")

                # Add listeners for all event types
                await connection.raw_connection.add_listener('pr_event', _pr_notification_handler)
                await connection.raw_connection.add_listener('pipeline_event', _pipeline_notification_handler)
                await connection.raw_connection.add_listener('insight_event', _insight_notification_handler)
                
                logger.success("DB Listener successfully connected. Listening for 'pr_event', 'pipeline_event', and 'insight_event' notifications.")

                # Keep the connection alive while the application is running
                while _running:
                    await asyncio.sleep(1)
                
                # If the loop was exited by a shutdown signal, clean up the listeners
                logger.info("Shutdown signal received, removing listeners...")
                await connection.raw_connection.remove_listener('pr_event', _pr_notification_handler)
                await connection.raw_connection.remove_listener('pipeline_event', _pipeline_notification_handler)
                await connection.raw_connection.remove_listener('insight_event', _insight_notification_handler)

        except asyncio.CancelledError:
            logger.warning("DB listener task was cancelled.")
            break  # Exit the main while loop immediately on cancellation

        except Exception as e:
            logger.error(f"DB listener task encountered an error: {e}. Reconnecting in 5 seconds...")
            # The `async with` block ensures the connection is closed on error.

        if _running:
            await asyncio.sleep(5)

    logger.info("Database notification listener has shut down.")