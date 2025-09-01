# api_service/app/services/event_poller.py

import asyncio
from loguru import logger
from app.data.database import db_helpers
from app.services.event_processor import process_event_by_id

_running = True

def stop_poller():
    global _running
    _running = False
    logger.info("Stop signal received for event poller.")

async def poll_for_events(is_fallback: bool = False):
    """
    Polls the database for unprocessed events. Can run as the primary mechanism
    or as a slow-running backup to a real-time listener.
    """
    sleep_interval = 30 if is_fallback else 2
    log_prefix = "Fallback Poller" if is_fallback else "Event Poller"
    logger.info(f"Starting {log_prefix} with {sleep_interval}s interval...")
    
    while _running:
        try:
            # Fetch one unprocessed event, oldest first.
            events = await db_helpers.select(
                "raw_events",
                where={"processed": False},
                order_by="received_at",
                limit=1
            )
            
            if events:
                event_to_process = events[0]
                event_id = event_to_process['id']
                logger.success(f"[{log_prefix}] Found new event to process: {event_id}")
                
                try:
                    # Process the event first. If it fails, an exception is raised.
                    await process_event_by_id(event_id)
                    
                    # ONLY if processing succeeds, mark it as processed.
                    await db_helpers.update(
                        "raw_events", data={"processed": True}, where={"id": event_id}
                    )
                    logger.info(f"[{log_prefix}] Successfully processed and marked event {event_id}.")
                
                except Exception as e:
                    # If processing fails, the event remains unprocessed for the next cycle.
                    logger.error(f"[{log_prefix}] Failed to process event {event_id}, it will be retried. Error: {e}")
                    # In case of failure, wait longer to prevent hammering a failing downstream service (e.g., AI API).
                    await asyncio.sleep(5)
            else:
                # No events found, sleep and wait.
                await asyncio.sleep(sleep_interval)

        except asyncio.CancelledError:
            logger.warning(f"[{log_prefix}] task was cancelled.")
            break
        except Exception as e:
            logger.error(f"[{log_prefix}] An unexpected error occurred in the loop: {e}. Retrying in 5s.")
            await asyncio.sleep(5)
    
    logger.info(f"{log_prefix} has shut down.")