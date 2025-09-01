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

async def poll_for_events():
    logger.info("Starting robust database event poller...")
    
    while _running:
        try:
            # Fetch one unprocessed event at a time to handle sequentially
            event_to_process = await db_helpers.select_one(
                "raw_events", where={"processed": False}, order_by="received_at"
            )

            if event_to_process:
                event_id = event_to_process['id']
                logger.success(f"Found new event to process: {event_id}")
                try:
                    # --- THE CORE LOGIC CHANGE ---
                    # Process the event first.
                    await process_event_by_id(event_id)
                    
                    # If and only if processing succeeds, mark it as processed.
                    await db_helpers.update(
                        "raw_events", data={"processed": True}, where={"id": event_id}
                    )
                    logger.info(f"Successfully processed and marked event {event_id}.")

                except Exception as e:
                    # If process_event_by_id raised an exception, we log it here.
                    # The event is NOT marked as processed and will be retried on the next poll cycle.
                    # This prevents losing events on transient errors (e.g., AI API outage).
                    logger.error(f"Failed to process event {event_id}, it will be retried. Error: {e}")
                    # Optional: Add a delay here to prevent rapid-fire retries on a persistent error.
                    await asyncio.sleep(5)
            else:
                # No events found, sleep and wait.
                await asyncio.sleep(2)

        except asyncio.CancelledError:
            logger.warning("Event poller task was cancelled.")
            break
        except Exception as e:
            logger.error(f"An unexpected error occurred in the event poller loop: {e}. Retrying in 5s.")
            await asyncio.sleep(5)
    
    logger.info("Event poller has shut down.")