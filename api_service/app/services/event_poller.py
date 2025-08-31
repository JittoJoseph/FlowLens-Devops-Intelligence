# api_service/app/services/event_poller.py

import asyncio
from loguru import logger
from app.data.database import db_helpers
from app.services.event_processor import process_event_by_id

_running = True

def stop_poller():
    global _running
    _running = False

async def poll_for_events():
    logger.info("Starting database event poller...")
    
    while _running:
        try:
            events_to_process = await db_helpers.select(
                "raw_events", where={"processed": False}, order_by="received_at"
            )

            if events_to_process:
                logger.success(f"Found {len(events_to_process)} new events to process.")
                for event in events_to_process:
                    event_id = event['id']
                    try:
                        await process_event_by_id(event_id)
                        
                        # --- THIS ONLY RUNS ON SUCCESS ---
                        await db_helpers.update(
                            "raw_events", data={"processed": True}, where={"id": event_id}
                        )
                        logger.info(f"Successfully marked event {event_id} as processed.")

                    except Exception as e:
                        # --- The processor now re-raises the exception on failure ---
                        # So we log it here, and the event is NOT marked as processed.
                        # It will be retried on the next poll cycle.
                        logger.error(f"Failed to process event {event_id}, it will be retried. Error: {e}")
            else:
                logger.trace("No new events found on this poll cycle.")

        except asyncio.CancelledError:
            logger.warning("Event poller task was cancelled.")
            break
        except Exception as e:
            logger.error(f"An error occurred in the event poller loop: {e}")
        
        await asyncio.sleep(2)