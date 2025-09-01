# api_service/app/data/database/core_db.py

from typing import Optional
from loguru import logger
from databases import Database
from app.data.configs.app_settings import settings

# --- Database State ---
database: Optional[Database] = None
# --- NEW: Dedicated connection for the listener ---
listener_db: Optional[Database] = None


def get_db() -> Database:
    """Returns the main database connection pool instance."""
    global database
    if database is None:
        database = Database(
            settings.DATABASE_URL,
            min_size=settings.POOL_MIN_SIZE,
            max_size=settings.POOL_MAX_SIZE,
        )
    return database

# --- NEW: Function to get the listener's dedicated connection ---
def get_listener_db() -> Database:
    """
    Returns a dedicated, lightweight Database instance for the listener.
    This ensures the listener's connection is never recycled by the main API pool.
    """
    global listener_db
    if listener_db is None:
        # We use a pool of 1 to ensure it's a single, dedicated connection.
        listener_db = Database(
            settings.LISTENER_DATABASE_URL,
            min_size=1,
            max_size=1,
        )
    return listener_db


async def connect():
    """Initializes all database connections on startup."""
    # Connect main pool
    db = get_db()
    if not db.is_connected:
        logger.info("Connecting main database pool...")
        try:
            await db.connect()
            logger.success("Main database pool connected.")
        except Exception as e:
            logger.critical("Could not connect main database pool", error=str(e))
            raise

    # --- NEW: Connect listener DB ---
    ldb = get_listener_db()
    if not ldb.is_connected:
        logger.info("Connecting dedicated DB listener...")
        try:
            await ldb.connect()
            logger.success("Dedicated DB listener connected.")
        except Exception as e:
            logger.critical("Could not connect dedicated DB listener", error=str(e))
            # Don't raise here, the app might still function in a degraded (polling) mode if we wanted.
            # But for this implementation, we'll treat it as critical.
            raise


async def disconnect():
    """Closes all connections in all pools on shutdown."""
    # Disconnect main pool
    db = get_db()
    if db.is_connected:
        logger.info("Closing main database pool...")
        await db.disconnect()
        logger.success("Main database pool closed.")
    
    # --- NEW: Disconnect listener DB ---
    ldb = get_listener_db()
    if ldb.is_connected:
        logger.info("Closing dedicated DB listener connection...")
        await ldb.disconnect()
        logger.success("Dedicated DB listener connection closed.")