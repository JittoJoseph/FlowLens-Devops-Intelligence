# api_service/app/services/db_listener.py
import asyncio
from loguru import logger
from app.data.database import core_db
from app.services.event_processor import process_event_by_id

async def listen_for_db_notifications():
    """
    Connects to the database and listens for notifications on the 'new_event' channel.
    """
    logger.info("Starting database notification listener...")
    pool = await core_db.get_pool()
    
    async with pool.acquire() as connection:
        await connection.add_listener('new_event', notification_handler)
        logger.success("Successfully listening for 'new_event' notifications.")
        
        # Keep the connection alive and listening indefinitely
        while True:
            await asyncio.sleep(60) # Keep-alive heartbeat

def notification_handler(connection, pid, channel, payload):
    """
    Callback function that is executed when a notification is received.
    It schedules the event processor to run in a non-blocking way.
    """
    logger.info(f"Received notification on channel '{channel}': New event ID is {payload}")
    # Run the processor in the background without blocking the listener
    asyncio.create_task(process_event_by_id(payload))