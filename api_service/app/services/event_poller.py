# api_service/app/services/event_poller.py

import asyncio
from loguru import logger
from app.data.database import db_helpers
from app.services.event_processor import process_event_by_id

_running = True

def stop_poller():
    """Signals the polling loop to stop."""
    global _running
    _running = False

async def poll_for_events():
    """
    The background task that polls the database for new, unprocessed events.
    """
    logger.info("Starting database event poller...")
    
    while _running:
        try:
            # --- THIS IS THE CORE POLLING LOGIC ---
            events_to_process = await db_helpers.select(
                "raw_events",
                where={"processed": False},
                order_by="received_at" # Process oldest first
            )

            if events_to_process:
                logger.success(f"Found {len(events_to_process)} new events to process.")
                for event in events_to_process:
                    event_id = event['id']
                    try:
                        # Process the event using the existing logic
                        await process_event_by_id(event_id)
                        
                        # --- CRITICAL STEP: Mark the event as processed ---
                        await db_helpers.update(
                            "raw_events",
                            data={"processed": True},
                            where={"id": event_id}
                        )
                        logger.info(f"Successfully marked event {event_id} as processed.")

                    except Exception as e:
                        logger.error(f"Failed to process event {event_id}, it will be retried.", exception=e)
            else:
                # This log is useful to know the poller is alive and running
                logger.trace("No new events found on this poll cycle.")

        except asyncio.CancelledError:
            logger.warning("Event poller task was cancelled.")
            break
        except Exception as e:
            logger.error(f"An error occurred in the event poller loop: {e}")
        
        # Wait for the next polling interval
        await asyncio.sleep(2)