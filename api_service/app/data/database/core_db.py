# api_service/app/data/database/core_db.py

from typing import Optional
from loguru import logger
from databases import Database
from app.data.configs.app_settings import settings

# --- Database State ---
database: Optional[Database] = None

def get_db() -> Database:
    """Returns the database instance."""
    global database
    if database is None:
        database = Database(
            settings.DATABASE_URL,
            min_size=settings.POOL_MIN_SIZE,
            max_size=settings.POOL_MAX_SIZE,
        )
    return database

async def connect():
    """Initializes the main database connection on startup."""
    db = get_db()
    if not db.is_connected:
        logger.info("Connecting to database...")
        try:
            await db.connect()
            logger.success("Database connection established.")
        except Exception as e:
            logger.critical("Could not connect to database", error=str(e))
            raise

async def disconnect():
    """Closes all connections in the pool on shutdown."""
    db = get_db()
    if db.is_connected:
        logger.info("Closing database connection...")
        await db.disconnect()
        logger.success("Database connection closed.")